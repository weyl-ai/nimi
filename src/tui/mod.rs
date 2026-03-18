//! TUI module for nimi — integration with mprocs for terminal UI
//!
//! This module provides conversion functions and utilities for integrating
//! nimi's process management with mprocs' terminal user interface.

pub mod config_dirs;
pub mod convert;

#[cfg(test)]
mod tests {
    use std::path::PathBuf;
    use std::time::Duration;

    use crate::config::Config;
    use crate::process_manager::service::{ArgV, ConfigData, ConfigDataMap, Process};
    use crate::process_manager::settings::{Logging, Restart, RestartMode, Startup};
    use crate::process_manager::{Service, Settings as NimiSettings};

    /// Helper to construct a Service with optional config_data
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

    /// Helper to construct a Config with multiple services
    fn make_config(services: Vec<(&str, Service)>) -> Config {
        let services_map = services
            .into_iter()
            .map(|(name, service)| (name.to_string(), service))
            .collect();

        Config {
            services: services_map,
            settings: make_nimi_settings(RestartMode::Never),
        }
    }

    /// Helper to construct NimiSettings with a given restart mode
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

    #[test]
    fn fixtures_construct() {
        // Test make_service with simple argv
        let _service1 = make_service(vec!["/nix/store/abc/bin/myapp", "--port", "8080"], false);

        // Test make_service with config_data
        let _service2 = make_service(vec!["/nix/store/abc/bin/myapp"], true);

        // Test make_config with multiple services
        let service_web = make_service(vec!["/nix/store/abc/bin/web"], false);
        let service_worker = make_service(vec!["/nix/store/abc/bin/worker"], false);
        let _config = make_config(vec![("web", service_web), ("worker", service_worker)]);

        // Test make_nimi_settings with all restart modes
        let _settings_never = make_nimi_settings(RestartMode::Never);
        let _settings_always = make_nimi_settings(RestartMode::Always);
        let _settings_up_to_count = make_nimi_settings(RestartMode::UpToCount);

        // All fixtures constructed successfully
    }
}
