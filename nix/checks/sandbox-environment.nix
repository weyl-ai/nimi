{
  writeShellApplication,
  nimi,
  testers,
  lib,
  coreutils,
  pkgs,
}:
let
  verifyEnv = writeShellApplication {
    name = "verify-sandbox-env";
    runtimeInputs = [ coreutils ];
    text = ''
      failed=0

      # Check environment variable
      if [[ "''${TEST_VAR:-}" != "test_value" ]]; then
        echo "FAIL: TEST_VAR expected test_value, got ''${TEST_VAR:-}"
        failed=1
      else
        echo "PASS: TEST_VAR is set correctly"
      fi

      # Check environment variable with equals sign in value
      if [[ "''${TEST_EQUALS:-}" != "foo=bar=baz" ]]; then
        echo "FAIL: TEST_EQUALS expected foo=bar=baz, got ''${TEST_EQUALS:-}"
        failed=1
      else
        echo "PASS: TEST_EQUALS is set correctly"
      fi

      # Check working directory
      if [[ "$PWD" != "/app" ]]; then
        echo "FAIL: WorkingDir expected '/app', got '$PWD'"
        failed=1
      else
        echo "PASS: WorkingDir is /app"
      fi

      # Check nix store is accessible
      if [[ ! -d /nix/store ]]; then
        echo "FAIL: /nix/store is not accessible"
        failed=1
      else
        echo "PASS: /nix/store is accessible"
      fi

      # Check volume is writable tmpfs
      if ! touch /data/test-file 2>/dev/null; then
        echo "FAIL: /data is not writable"
        failed=1
      else
        echo "PASS: /data volume is writable"
        rm /data/test-file
      fi

      # Check root filesystem is writable (overlay working)
      # Write a file with unique content that we can verify doesn't leak to host
      if ! echo "SANDBOX_WRITE_TEST_MARKER" > /app/sandbox-write-test 2>/dev/null; then
        echo "FAIL: root filesystem is not writable (overlay not working)"
        failed=1
      else
        echo "PASS: root filesystem is writable (overlay working)"
      fi

      exit $failed
    '';
  };

  rootfs = pkgs.runCommand "sandbox-root" { } ''
    mkdir -p $out/app $out/data
  '';

  sandbox = nimi.mkSandbox {
    services."verify-env" = {
      process.argv = [ (lib.getExe verifyEnv) ];
    };
    settings.restart.mode = "never";
    settings.container = {
      copyToRoot = [ rootfs ];
      imageConfig = {
        Env = [
          "TEST_VAR=test_value"
          "TEST_EQUALS=foo=bar=baz"
        ];
        WorkingDir = "/app";
        Volumes = {
          "/data" = { };
        };
      };
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

    # Verify that writes inside sandbox don't affect the original rootfs
    machine.succeed("test ! -f ${rootfs}/app/sandbox-write-test")
    print("PASS: sandbox writes do not leak to host rootfs")
  '';
}
