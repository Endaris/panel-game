return {
  
  -- basic settings:
  name = 'Panel Attack', -- name of the game for your executable
  developer = 'Panel Attack Devs', -- dev name used in metadata of the file
  output = 'dist', -- output location for your game, defaults to $SAVE_DIRECTORY
  version = '048', -- 'version' of your game, used to name the folder in output
  love = '12.0', -- version of LÖVE to use, must match github releases
  ignore = {
    'dist',
    'server',
    'updater',
    'notes',
    'profiling',
    '.vscode',
    '.VSCodeCounter',
    '.github',
    '.gitignore',
    '.gitignore-template',
    'csprng_seed.txt',
    'GameResults.csv',
    'leaderboard.csv',
    'PADatabase.sqlite3',
    'players.txt',
    'placement_matches',
    'ftp',
    'reports',
  }, -- folders/files to ignore in your project
  icon = "client/assets/panels/__default/panel11.png", -- 256x256px PNG icon for game, will be converted for you

  platforms = {'linux'} -- set if you only want to build for a specific platform
  
}