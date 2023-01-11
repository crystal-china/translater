# bing_translater

由于众所周知的原因，谷歌翻译中国境内用不了。

而网上找到的大部分命令行工具或浏览器插件都是基于谷歌翻译，偶尔
因为网的原因无法翻译，不太方便，因此，写了这个工具。

## Installation

从 [release](https://github.com/crystal-china/bing_translater/releases) 下载最新版，扔到加入你的 $PATH 的文件夹里，直接使用

## Usage

```sh
 ╰─ $ bing_translater "Hello China!"
你好中国！
╰─ $ bing_translater -t en "你好，中国！"
Hello, China!
```

目前只支持中英互译，有时间，可以新增更多的支持。

**注意：**

bing 翻译针对单个 IP 单位时间内会有限制，具体位置，你只要不是非常频繁的使用，
应该没问题的。

## Contributing

1. Fork it (<https://github.com/zw963/bing_translater/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Billy.Zheng](https://github.com/zw963) - creator and maintainer
