{ }:
{
  mkRepoConfigSymlink =
    {
      config,
      nixDirectory,
      path,
    }:
    config.lib.file.mkOutOfStoreSymlink "${nixDirectory}/config/${path}";
}
