XDG_DATA_HOME = Path[ENV.fetch("XDG_DATA_HOME", "~/.local/share")]

def find_db_path(name)
  default_path = (
    XDG_DATA_HOME /
    "translater" /
    name
  ).expand(home: true)

  db_file_paths = {
    default_path,
    (Path["#{Process.executable_path.as(String)}/../.."] / name).expand,
    Path["~/.#{name}"].expand(home: true),
  }

  db_file_paths.each do |path|
    return path if File.exists?(path)
  end

  Dir.mkdir_p(default_path.dirname)

  default_path
end

PROFILE_DB_FILE  = "sqlite3:#{find_db_path("profile.db")}"
SESSION_DB_FILE  = "sqlite3:#{find_db_path("session.db")}"
ENGINE_INIT_FILE = find_db_path("engines").to_s

def profile_db_exists?
  db_file = PROFILE_DB_FILE.split(':')[1]

  File.exists?(db_file) && File.info(db_file).size > 0
end
