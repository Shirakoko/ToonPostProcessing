# 使用Unity内置管线实现卡渲染后处理效果
原文：[捣鼓记录：【Unity内置管线】绘画色彩理论在卡渲后处理中的应用 | 白雪万事屋](https://www.shirakoko.xyz/article/built-in-postprocess)

## 柔光效果

- Shaders/PostEffectShaders/Diffuse.shader
- Scripts/PostEffextScripts/DiffuseEffect.cs

![Diffuse](Pictures/Diffuse.jpg)

## 背景透光效果

- Shaders/PostEffectShaders/Backlit.shader
- Scripts/PostEffextScripts/BacklitEffect.cs

![Backlit](Pictures/Backlit.jpg)

## 暗部晕染效果

- Shaders/PostEffectShaders/DarkBlur.shader
- Scripts/PostEffextScripts/DarkBlur.cs

![DarkBlur](Pictures/DarkBlur.jpg)

备注：目前的三种效果是分开实现的，有空再更新三合一的后处理脚本
