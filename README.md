# translater

由于众所周知的原因，谷歌翻译中国境内用不了。

而网上找到的大部分命令行工具或浏览器插件都是基于谷歌翻译，不太方便，因此，写了这个工具。

当前支持的翻译引擎：有道翻译、腾讯翻译君、阿里翻译、百度翻译。

translater 会启动一个 headless 模式的浏览器内核（Firefox/Chrome) 随机访问上面的一个翻译网站获取翻译, 
默认使用 Chrome 内核, 因此要求系统必须已安装 Chrome.

从 v0.4.8 版本开始，translater 不再为用户自动安装 Chrome Selenium driver(chromedriver).
作为用户，你必须确保安装正确匹配版本的 chrome/chromium 与 chromedriver.
你可以使用系统包管理安装 chromedriver, 或自己下载，并拷贝至 /usr/local/bin.

v0.3.0 版本引入了一个小数据库，会记录每次不同引擎翻译的耗时，用来分析那个翻译引擎速度快一些。

```sh
 ╰─ $ translater --profile
youdao average elapsed_seconds: 453.4 msecs for 5 samples
baidu average elapsed_seconds: 513.0 msecs for 10 samples
ali average elapsed_seconds: 514.2 msecs for 5 samples
tencent average elapsed_seconds: 3320.285714285714 msecs for 7 samples
```

看起来 `有道` 在我这里速度快一些，用户可以根据返回的结果，
自己指定翻译引擎，例如，下面的代码指定使用百度翻译。

```sh
$: translater -e 'baidu' 'hello world!'
---------------Baidu---------------
你好世界
```

`translater --help` 获取更多参数的帮助。

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

```sh
 ╰─ $ translater "Hello China!"
---------------Youdao--------------- 
你好中国！

╰─ $ translater "你好，中国！"
---------------Alibaba--------------- 
Hello, China!
```

只支持中英互译，根据源语言自动判断。

## TODO

1. 支持 Edge

## Contributing

1. Fork it (<https://github.com/zw963/translater/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Billy.Zheng](https://github.com/zw963) - creator and maintainer
