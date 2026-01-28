{
  nimi,
  lib,
  redis,
}:
nimi.mkSandbox {
  services."redis" = {
    process.argv = [ "${lib.getExe' redis "redis-server"}" ];
  };
}
