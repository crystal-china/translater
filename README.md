# translater

由于众所周知的原因，谷歌翻译中国境内用不了。

而网上找到的大部分命令行工具或浏览器插件都是基于谷歌翻译，不太方便，因此，写了这个工具。

当前支持的引擎：有道翻译、腾讯翻译君、阿里翻译、百度翻译、必应翻译，

`translater --help` 查看如何指定翻译引擎，默认随机选择。

## Installation

从 [release](https://github.com/crystal-china/translater/releases) 下载（单文件）最新版，
扔到 $PATH 的文件夹里，直接使用

## Usage

```sh
 ╰─ $ translater "Hello China!"
---------------Youdao--------------- 
你好中国！

╰─ $ translater "你好，中国！"
---------------Alibaba--------------- 
Hello, China!
```

目前只支持中英互译，根据源语言自动判断。

## Contributing

1. Fork it (<https://github.com/zw963/translater/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Billy.Zheng](https://github.com/zw963) - creator and maintainer
