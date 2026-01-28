{
  writeShellApplication,
  nimi,
  testers,
  lib,
  coreutils,
}:
let
  verifyEnv = writeShellApplication {
    name = "verify-sandbox-env";
    runtimeInputs = [ coreutils ];
    text = ''
      failed=0

      echo "Testing environment variable..."
      if [[ "''${TEST_VAR:-}" != "test_value" ]]; then
        echo "FAIL: TEST_VAR expected test_value, got ''${TEST_VAR:-}"
        failed=1
      else
        echo "PASS: TEST_VAR is set correctly"
      fi

      echo "Testing working directory..."
      if [[ "$PWD" != "/app" ]]; then
        echo "FAIL: WorkingDir expected '/app', got '$PWD'"
        failed=1
      else
        echo "PASS: WorkingDir is /app"
      fi

      echo "Testing nix store is accessible..."
      if [[ ! -d /nix/store ]]; then
        echo "FAIL: /nix/store is not accessible"
        failed=1
      else
        echo "PASS: /nix/store is accessible"
      fi

      echo "Testing volume is writable tmpfs..."
      if ! touch /data/test-file 2>/dev/null; then
        echo "FAIL: /data is not writable"
        failed=1
      else
        echo "PASS: /data volume is writable"
        rm /data/test-file
      fi

      exit $failed
    '';
  };

  sandbox = nimi.mkBwrap {
    settings.startup.runOnStartup = lib.getExe verifyEnv;
    settings.bubblewrap = {
      environment = {
        TEST_VAR = "test_value";
      };
      extraTmpfs = [
        "/data"
        "/app"
      ];
      chdir = "/app";
    };
  };
in
testers.runNixOSTest {
  name = "sandbox-environment";
  nodes.machine = { };
  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    output = machine.succeed("${lib.getExe sandbox} 2>&1")
    print(output)

    if "FAIL:" in output:
        raise Exception("Some sandbox checks failed")
  '';
}
