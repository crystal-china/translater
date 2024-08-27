How to use AI as a local translate engine on my Arch Linux.

## install [ollama](https://github.com/ollama/ollama).

## You probably need install CUDA drivers for nvidia GPUs or ROCm drivers for AMD GPUs for better performance.

I'm using an AMD 7840HS computer (with the integrated 780M iGPU), and you can install it by following these steps:

1. Install GPU drivers

```sh
$: sudo pacman -S amdvlk lib32-amdvlk
```

2. install ROCm packages

```sh
$: sudo pacman -S rocm-hip-sdk rocm-opencl-sdk
```

3. Install tools for monitor GPU usage (optional)

```sh
pacman -S radeontop

# OR

pacman -S nvtop
```

## Confug ollama service.

```systemd
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
Environment="HSA_OVERRIDE_GFX_VERSION=11.0.0"
Environment="OLLAMA_KEEP_ALIVE=-1"
ExecStart=/home/zw963/utils/llms/bin/ollama serve
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
```

systemctl --user enable ollama
systemctl --user start ollama

## Run models

```sh
$: ollama run qwen2:7b
```

## Wrote a bash scripts like this:

```bash
#!/usr/bin/env bash

model=qwen2

if [ $# == 0 ]; then
    content=$(cat /proc/$$/fd/0);
else
    content="$1"
fi

if echo "$content" |grep -P '[\p{Han}]' >/dev/null; then
    tmpfile=/tmp/ai_translater.txt
    ollama run $model "Translate Simplified Chinese into English: $content" | tee $tmpfile
    cat $tmpfile |sed '/^[[:space:]]*$/d' |sed 's/[ \t]*$//'|tr -d '\n' |xclip -selection clipboard
else

    ollama run $model "Translate English into Simplified Chinese: $content"
fi
```

## Add it into goldendict as a dictionary (optional)

Then, You can select a piece of text with your mouse, then use a shortcut key to translate it.

It can recognize Chinese and translate it to English, or vice versa.

