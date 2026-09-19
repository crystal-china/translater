require "./spec_helper"

record CLIResult, status : Process::Status, output : String, error : String

private def run_cli(arguments, env = nil) : CLIResult
  output = IO::Memory.new
  error = IO::Memory.new
  executable = Path[__DIR__, "..", "bin", "translater"].normalize.to_s
  status = Process.run(executable, arguments, env: env, output: output, error: error)

  CLIResult.new(status, output.to_s, error.to_s)
end

describe EngineResult do
  it "distinguishes successful and failed engine results" do
    success = EngineResult.new(Engine::Ali, "你好", 1.second, Browser::Firefox, false, nil)
    empty = EngineResult.new(Engine::Ali, "", 1.second, Browser::Firefox, false, nil)
    failure = EngineResult.new(Engine::Ali, nil, 1.second, Browser::Firefox, false, Exception.new("failed"))

    success.success?.should be_true
    empty.success?.should be_false
    failure.success?.should be_false
  end
end

describe "translater CLI" do
  it "prints the package version" do
    result = run_cli(["--version"])

    result.status.success?.should be_true
    result.output.should contain(Translater::VERSION)
  end

  it "rejects an unknown engine" do
    result = run_cli(["--engine=unknown", "hello"])

    result.status.success?.should be_false
    result.error.should contain("Supported options")
  end

  it "rejects a non-positive timeout" do
    result = run_cli(["--timeout=0", "hello"])

    result.status.success?.should be_false
    result.error.should contain("positive integer")
  end

  it "rejects skipping every engine" do
    result = run_cli(["--skip=ali,baidu,bing,youdao", "hello"])

    result.status.success?.should be_false
    result.error.should contain("At least one engine")
  end

  it "reports an empty profile instead of crashing" do
    data_home = Path[Dir.tempdir] / "translater-spec-#{Process.pid}-#{Time.utc.to_unix_ms}"
    Dir.mkdir_p(data_home)
    env = {"XDG_DATA_HOME" => data_home.to_s}

    begin
      run_cli(["--profile"], env).status.success?.should be_true
      result = run_cli(["--profile"], env)

      result.status.success?.should be_true
      result.error.should contain("No profile samples exist yet")
    ensure
      FileUtils.rm_r(data_home) if File.exists?(data_home)
    end
  end
end
