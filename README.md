# translater

基于多个翻译引擎的整句翻译命令行工具。

当前支持的翻译引擎：有道翻译、腾讯翻译君、阿里翻译、百度翻译，无需翻墙哦！

特点：

1. 适合中英文整句翻译，如果需要单词翻译工具，以及详细的单词释义，这个不适合你。
2. 多个引擎并行同时翻译，见下面的例子。


```sh
 ╰─ $ ./bin/translater -A '那些杀不死你的，终将使你变得更强大'
Using Youdao Tencent Ali Baidu 
---------------Tencent, spent 4.52 seconds---------------
Those who can't kill you will eventually make you stronger.
---------------Youdao, spent 6.35 seconds---------------
What doesn't kill you makes you stronger
---------------Ali, spent 6.65 seconds---------------
What doesn't kill you will make you stronger., 
---------------Baidu, spent 6.71 seconds---------------
Those who cannot kill you will eventually make you stronger

```

```sh
 ╰─ $ ./bin/translater -A "What Doesn't Kill You Makes You Stronger"
Using Youdao Tencent Ali Baidu 
---------------Baidu, spent 6.15 seconds---------------
凡是没能击垮你的，都使你变得更强
---------------Youdao, spent 6.22 seconds---------------
那些杀不死你的，会让你更强大
---------------Tencent, spent 8.91 seconds---------------
摧毁不了你的东西会让你更强
---------------Ali, spent 9.69 seconds---------------
杀不死你的东西会让你更强大, 
```

## Installation

从 [release 页面](https://github.com/crystal-china/translater/releases) 下载（单文件）最新版，
扔到 $PATH 的文件夹里，目前支持 Linux 和 OSX.

或者从源码编译安装：
《
```sh
$: make release
$: sudo make install
```

translater 会启动一个 headless 模式的浏览器内核（Firefox/Chrome) 随机访问一个翻译网站获取翻译, 
默认使用 Chrome 内核, 因此要求系统必须已安装 Chrome.

从 v0.4.8 版本开始，translater 不再为用户自动安装 chromedriver (Chrome Selenium driver).
作为用户，你必须确保安装正确匹配版本的 chrome/chromium 与 chromedriver.
你可以使用系统包管理安装 chromedriver, 或自己下载可执行文件，并拷贝至 /usr/local/bin.

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

v0.3.0 版本引入了一个小数据库，会自动记录每次不同引擎翻译的耗时，可以使用 --profile 分析那个翻译引擎速度快一些。

```sh
 ╰─ $ translater --profile
youdao average elapsed_seconds: 453.4 msecs for 5 samples
baidu average elapsed_seconds: 513.0 msecs for 10 samples
ali average elapsed_seconds: 514.2 msecs for 5 samples
tencent average elapsed_seconds: 3320.285714285714 msecs for 7 samples
```

看起来 `有道` 在我这里速度快一些，用户可以根据返回的结果，自己指定翻译引擎，例如，下面的代码指定使用百度翻译。

```sh
$: translater -e 'baidu' 'hello world!'
---------------Baidu---------------
你好世界
```

`translater --help` 获取更多参数的帮助。

## TODO

1. 支持 Edge
2. 当使用 selenium 启动一个浏览器进程并访问火山翻译主页时, 甚至手动输入翻译内容也不工作.

## Contributing

1. Fork it (<https://github.com/zw963/translater/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Billy.Zheng](https://github.com/zw963) - creator and maintainer
