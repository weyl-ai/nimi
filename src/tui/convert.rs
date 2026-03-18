// Conversion functions: nimi types → mprocs types

use std::collections::HashMap;
use std::path::Path;

use crate::config::Config;
use crate::process_manager::settings::{Restart, RestartMode};
use crate::process_manager::{Service, Settings as NimiSettings};
use lib::{CmdConfig, ProcConfig, StopSignal};

pub fn convert_service(
    name: &str,
    service: &Service,
    settings: &NimiSettings,
    config_dir: Option<&Path>,
) -> ProcConfig {
    let cmd: Vec<String> = std::iter::once(service.process.argv.binary().to_owned())
        .chain(service.process.argv.args().iter().cloned())
        .collect();

    let env = config_dir.map(|dir| {
        std::iter::once((
            "XDG_CONFIG_HOME".to_string(),
            Some(dir.to_string_lossy().to_string()),
        ))
        .collect()
    });

    let defaults = lib::Settings::default();

    ProcConfig {
        name: name.to_owned(),
        cmd: CmdConfig::Cmd { cmd },
        cwd: None,
        env,
        autostart: true,
        autorestart: convert_autorestart(&settings.restart),
        stop: StopSignal::default(),
        deps: Vec::new(),
        mouse_scroll_speed: defaults.mouse_scroll_speed,
        scrollback_len: defaults.scrollback_len,
        log: None,
    }
}

// NOTE: UpToCount maps to true — lossy because mprocs has no restart count limit
fn convert_autorestart(restart: &Restart) -> bool {
    match restart.mode {
        RestartMode::Never => false,
        RestartMode::Always | RestartMode::UpToCount => true,
    }
}

pub fn convert_config(
    config: &Config,
    config_dirs: &HashMap<String, std::path::PathBuf>,
) -> (Vec<ProcConfig>, lib::Settings) {
    let mprocs_settings = lib::Settings::default();

    let procs = config
        .services
        .iter()
        .map(|(name, service)| {
            let config_dir = config_dirs.get(name).map(|p| p.as_path());
            convert_service(name, service, &config.settings, config_dir)
        })
        .collect();

    (procs, mprocs_settings)
}

pub fn convert_settings() -> lib::Settings {
    lib::Settings::default()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;
    use std::time::Duration;

    use crate::process_manager::service::{ArgV, ConfigData, ConfigDataMap, Process};
    use crate::process_manager::settings::{Logging, Restart, RestartMode, Startup};

    fn make_service(argv: Vec<&str>, with_config_data: bool) -> Service {
        let argv_strings: Vec<String> = argv.iter().map(|s| s.to_string()).collect();
        let argv = ArgV::try_from(argv_strings).expect("Failed to create ArgV");

        let config_data = if with_config_data {
            let mut map = ConfigDataMap::new();
            map.insert(
                "config".to_string(),
                ConfigData {
                    enable: true,
                    path: PathBuf::from("etc/myapp/config"),
                    text: None,
                    source: PathBuf::from("/nix/store/abc/myapp-config"),
                },
            );
            map
        } else {
            ConfigDataMap::new()
        };

        Service {
            config_data,
            process: Process { argv },
        }
    }

    fn make_nimi_settings(mode: RestartMode) -> NimiSettings {
        NimiSettings {
            restart: Restart {
                mode,
                time: Duration::from_millis(1000),
                count: 3,
            },
            startup: Startup {
                run_on_startup: None,
            },
            logging: Logging { logs_dir: None },
        }
    }

    fn make_config_with_restart(services: Vec<(&str, Service)>, mode: RestartMode) -> Config {
        let services_map = services
            .into_iter()
            .map(|(name, svc)| (name.to_string(), svc))
            .collect();

        Config {
            services: services_map,
            settings: make_nimi_settings(mode),
        }
    }

    #[test]
    fn test_service_argv_preserved() {
        let service = make_service(vec!["/nix/store/abc/bin/myapp", "--port", "8080"], false);
        let settings = make_nimi_settings(RestartMode::Never);
        let proc = convert_service("myapp", &service, &settings, None);

        match &proc.cmd {
            CmdConfig::Cmd { cmd } => {
                assert_eq!(
                    cmd,
                    &vec![
                        "/nix/store/abc/bin/myapp".to_string(),
                        "--port".to_string(),
                        "8080".to_string(),
                    ]
                );
            }
            CmdConfig::Shell { .. } => panic!("Expected CmdConfig::Cmd, got Shell"),
        }
    }

    #[test]
    fn test_service_with_config_data_sets_env() {
        let service = make_service(vec!["/nix/store/abc/bin/myapp"], true);
        let settings = make_nimi_settings(RestartMode::Never);
        let config_dir = PathBuf::from("/tmp/test-cfg");
        let proc = convert_service("myapp", &service, &settings, Some(&config_dir));

        let env = proc
            .env
            .expect("env should be Some when config_dir is provided");
        let xdg = env.get("XDG_CONFIG_HOME").expect("XDG_CONFIG_HOME missing");
        assert_eq!(xdg, &Some("/tmp/test-cfg".to_string()));
    }

    #[test]
    fn test_service_without_config_data_no_env() {
        let service = make_service(vec!["/nix/store/abc/bin/myapp"], false);
        let settings = make_nimi_settings(RestartMode::Never);
        let proc = convert_service("myapp", &service, &settings, None);

        assert!(proc.env.is_none());
    }

    #[test]
    fn test_restart_never() {
        let restart = Restart {
            mode: RestartMode::Never,
            time: Duration::from_millis(1000),
            count: 3,
        };
        assert!(!convert_autorestart(&restart));
    }

    #[test]
    fn test_restart_always() {
        let restart = Restart {
            mode: RestartMode::Always,
            time: Duration::from_millis(1000),
            count: 3,
        };
        assert!(convert_autorestart(&restart));
    }

    #[test]
    fn test_restart_up_to_count() {
        let restart = Restart {
            mode: RestartMode::UpToCount,
            time: Duration::from_millis(1000),
            count: 5,
        };
        assert!(convert_autorestart(&restart));
    }

    #[test]
    fn test_full_config_two_services() {
        let service_web = make_service(vec!["/nix/store/abc/bin/web"], false);
        let service_worker = make_service(vec!["/nix/store/abc/bin/worker"], false);
        let config = make_config_with_restart(
            vec![("web", service_web), ("worker", service_worker)],
            RestartMode::Always,
        );

        let config_dirs = HashMap::new();
        let (procs, _settings) = convert_config(&config, &config_dirs);

        assert_eq!(procs.len(), 2);

        let names: Vec<&str> = procs.iter().map(|p| p.name.as_str()).collect();
        assert!(names.contains(&"web"));
        assert!(names.contains(&"worker"));

        for proc in &procs {
            assert!(
                proc.autorestart,
                "{} should have autorestart=true",
                proc.name
            );
        }
    }

    #[test]
    fn test_empty_config() {
        let config = make_config_with_restart(vec![], RestartMode::Never);
        let config_dirs = HashMap::new();
        let (procs, _settings) = convert_config(&config, &config_dirs);

        assert!(procs.is_empty());
    }

    #[test]
    fn test_settings_default() {
        let settings = convert_settings();
        assert_eq!(settings.mouse_scroll_speed, 5);
        assert_eq!(settings.scrollback_len, 1000);
    }
}
