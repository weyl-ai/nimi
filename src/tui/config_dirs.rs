// ConfigDir batch pre-creation utility
// Implemented in Task 5

use std::{collections::HashMap, env, path::PathBuf};
use eyre::Result;
use crate::config::Config;
use crate::process_manager::service_manager::ConfigDir;

/// Pre-create all ConfigDirs for services that have enabled config_data.
/// Returns a map from service name → path of the created ConfigDir.
/// Must be called BEFORE mprocs launch.
pub async fn create_config_dirs(config: &Config) -> Result<HashMap<String, PathBuf>> {
    let tmp_dir = env::temp_dir();
    let mut result = HashMap::new();
    
    for (name, service) in &config.services {
        // Only create ConfigDir if there are enabled config_data entries
        let has_enabled = service.config_data.values().any(|cd| cd.enable);
        if !has_enabled {
            continue;
        }
        
        let _config_dir = ConfigDir::new(&tmp_dir, &service.config_data).await?;
        // Compute the path using generate_config_directory_name (public method)
        let dir_name = ConfigDir::generate_config_directory_name(&service.config_data)?;
        let path = tmp_dir.join(&dir_name);
        result.insert(name.clone(), path);
    }
    
    Ok(result)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;
    use crate::config::Config;
    use crate::process_manager::Service;
    use crate::process_manager::service::{ConfigDataMap, Process, ConfigData, ArgV};
    use crate::process_manager::settings::{Logging, Restart, RestartMode, Startup};
    use crate::process_manager::Settings as NimiSettings;
    use std::time::Duration;
    use tempfile::TempDir;

    fn make_service_with_config_data() -> Service {
        let argv = ArgV::try_from(vec!["/bin/echo".to_string()]).unwrap();
        let mut config_data = ConfigDataMap::new();
        
        // Create a temporary source file for the symlink
        let tmp = TempDir::new().unwrap();
        let fake_source = tmp.path().join("config-file");
        std::fs::write(&fake_source, b"fake config content").unwrap();
        
        config_data.insert("cfg".to_string(), ConfigData {
            enable: true,
            path: PathBuf::from("etc/app/config"),
            text: None,
            source: fake_source,
        });
        Service {
            config_data,
            process: Process { argv },
        }
    }
    
    fn make_service_no_config_data() -> Service {
        let argv = ArgV::try_from(vec!["/bin/echo".to_string()]).unwrap();
        Service {
            config_data: ConfigDataMap::new(),
            process: Process { argv },
        }
    }
    
    fn make_config(services: Vec<(&str, Service)>) -> Config {
        let settings = NimiSettings {
            restart: Restart { mode: RestartMode::Never, time: Duration::from_millis(100), count: 0 },
            startup: Startup { run_on_startup: None },
            logging: Logging { logs_dir: None },
        };
        Config {
            services: services.into_iter().map(|(n, s)| (n.to_string(), s)).collect(),
            settings,
        }
    }

    #[tokio::test]
    async fn test_batch_creates_dirs_for_services_with_config_data() {
        let config = make_config(vec![
            ("web", make_service_with_config_data()),
            ("worker", make_service_no_config_data()),
        ]);
        let result = create_config_dirs(&config).await.unwrap();
        assert!(result.contains_key("web"), "web should have a ConfigDir");
        assert!(!result.contains_key("worker"), "worker should NOT have a ConfigDir");
        assert_eq!(result.len(), 1);
    }

    #[tokio::test]
    async fn test_batch_keys_match_service_names() {
        let config = make_config(vec![("my-service", make_service_with_config_data())]);
        let result = create_config_dirs(&config).await.unwrap();
        assert!(result.contains_key("my-service"));
    }

    #[tokio::test]
    async fn test_config_dir_path_exists_on_disk() {
        let config = make_config(vec![("svc", make_service_with_config_data())]);
        let result = create_config_dirs(&config).await.unwrap();
        let path = result.get("svc").unwrap();
        assert!(std::fs::metadata(path).unwrap().is_dir());
    }

    #[tokio::test]
    async fn test_empty_config_data_skipped() {
        let argv = ArgV::try_from(vec!["/bin/echo".to_string()]).unwrap();
        let mut config_data = ConfigDataMap::new();
        
        // Create a temporary source file for the symlink
        let tmp = TempDir::new().unwrap();
        let fake_source = tmp.path().join("config-file");
        std::fs::write(&fake_source, b"fake config content").unwrap();
        
        config_data.insert("cfg".to_string(), ConfigData {
            enable: false,  // DISABLED
            path: PathBuf::from("etc/app/config"),
            text: None,
            source: fake_source,
        });
        let svc = Service { config_data, process: Process { argv } };
        let config = make_config(vec![("disabled-svc", svc)]);
        let result = create_config_dirs(&config).await.unwrap();
        assert!(result.is_empty(), "Disabled config_data should not create ConfigDir");
    }
}
