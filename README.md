# translater

基于多个翻译引擎的整句翻译命令行工具，支持有道翻译、腾讯翻译君、阿里翻译、百度翻译、必应翻译，无需翻墙哦！

适合中英文整句互译，如果需要单词翻译工具，以及详细的单词释义，这个不适合你。

会根据要翻译的语言自动判断，只支持中英互译。

```sh
  ╰─ $ bin/translater 'hello world'
Using Baidu
---------- Baidu, spent 7.67 seconds use Firefox ----------
你好世界
```

仅支持火狐浏览器以及 geckodriver（selenium driver for Firefox) 
因为使用了浏览器 cache, 某一翻译引擎运行一次之后，如果再次选择该引擎，速度将得到极大提升。

```sh
╰─ $ bin/translater 'hello world'
Using Baidu
---------- Baidu, spent 3.29 seconds use Firefox cache ----------
你好世界

 ╰─ $ bin/translater 'hello world'
Using Youdao
---------- Youdao, spent 6.35 seconds use Firefox ----------
你好世界。

 ╰─ $ bin/translater 'hello world'
Using Youdao
Using exists session for Youdao
---------- Youdao, spent 1.58 seconds use Firefox cache ----------
你好世界。

```

`translater --help` 获取有关参数的更多帮助。

## Dependencies

### Firefox 浏览器及 geckodriver
translater 会启动一个 headless 模式的火狐(Firefox)浏览器内核访问一个随机翻译网站获取翻译.

从 v0.4.8 版本开始，translater 不再为用户自动安装 geckodriver，你必须正确安装 Firefox 浏览器
以及匹配的 geckodriver 版本，以 Arch Linux 为例：

```sh
$: pacman -S firefox geckodriver
```

或安装 Firefox 之后，自己下载 geckodriver，并拷贝至 /usr/local/bin

### Sqlite3

translater 使用 Sqlite3 保存缓存的 session，来加速翻译流程。

translster 同时还维护一个最快引擎的数据库，会自动记录每次不同引擎翻译的耗时，
可以使用 --profile 初始化数据库以及分析那个翻译引擎速度快一些。，见：--auto 以及 --profile 选项。

## Installation

从 [release 页面](https://github.com/crystal-china/translater/releases) 下载（单文件）最新版，
扔到 $PATH 的文件夹里，目前支持 Linux 和 OSX.

或者从源码编译安装：
《
```sh
$: make release
$: sudo make install
```

## Usage

避免过于频繁的使用某一翻译而导致 IP 被封，建议直接运行即可，将使用随机引擎用于翻译：

```sh
 ╰─ $ bin/translater '你好，世界'
Using Baidu
---------- Baidu, spent 2.65 seconds use Firefox cache ----------
Hello, World
```

```sh
╰─ $ bin/translater 'hello world'
Using Youdao
---------- Youdao, spent 6.35 seconds use Firefox ----------
你好世界。
```

## TODO

2. 支持字节的火山翻译引擎, 当前，甚至非 headless 启动，手动输入翻译内容也不工作。

## Contributing

1. Fork it (<https://github.com/zw963/translater/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Billy.Zheng](https://github.com/zw963) - creator and maintainer
