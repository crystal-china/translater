require "./spec_helper"

describe "Translater" do
  before_all do
    system("shards build")
    system("./bin/translater --profile")
  end

  it "no args should work", tags: "ci" do
    system("./bin/translater").should be_true
  end

  # it "translate E/C use all supported engines", tags: "ci" do
  #   system("./bin/translater -A 'Hello, China!'").should be_true
  # end

  it "translate C/E use default engine", tags: "ci" do
    system("./bin/translater '你好，中国！'").should be_true
  end

  it "translate C/E use default engine", tags: "ci" do
    system("./bin/translater '你好，中国！'").should be_true
  end

  it "translate C/E use youdao" do
    system("./bin/translater -e youdao '你好，中国！'").should be_true
  end

  it "translate E/C use youdao" do
    system("./bin/translater -e youdao 'Hello, China!'").should be_true
  end

  it "translate C/E use baidu" do
    system("./bin/translater -e baidu '你好，中国！'").should be_true
  end

  it "translate C/E use ali" do
    system("./bin/translater -e ali '你好，中国！'").should be_true
  end

  it "translate C/E use tencent" do
    system("./bin/translater -e tencent '你好，中国！'").should be_true
  end

  it "translate E/C use youdao+baidu" do
    system("./bin/translater -e baidu,youdao 'Hello, China!'").should be_true
  end

  it "should translate multi-line english" do
    system(%{./bin/translater "Specify target language, support zh-CN|en for now.
  default is translate English to Chinese.
  Youdao don't support this option."}).should be_true
  end

  it "select the fastest engine", tags: "ci" do
    system("./bin/translater -a 'Hello, China!'").should be_true
  end

  it "should be false" do
    system("./bin/translater -e nonsupported_engine '你好，中国！'").should be_false
  end
end
