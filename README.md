# Eureka (尤里卡)

一款手机端的 AI 学习强化训练应用。选择科目 → 生成学习路线 → 逐知识点讲解 → 答题评分 → 掌握度门控 → 遗忘曲线复习。

名字源自阿基米德的 "Eureka!"(我发现了!)——知识顿悟的那一刻。

## 特性

- **单科目强化训练**:聚焦一门学科,书单 → 知识点 → 掌握度,练完真会
- **掌握度门控**:每个知识点达到 90%(重要内容 95%)才算掌握,防止蒙对一次就过关
- **三种学习模式**:速学(记忆型)/ 深度(概念型)/ 挑战(程序型),对应不同教学方式
- **价值系数分级**:书单按 神级/优质/中等/基础/拓展 五档标注重要程度,重要内容投入更多
- **游戏化**:等级 / XP / 连续签到 / 徽章 / 书架
- **遗忘曲线复习**:按记忆规律安排到期复习(开发中)
- **语音输入**:支持语音回答

## 技术栈

- Flutter (移动端 APK)
- 后端:OpenAI 兼容 API(DeepSeek / 阿里云百炼 / SiliconFlow)

## 配置

在 设置 中填入你的 API Key 即可使用:

| 后端 | 说明 |
|------|------|
| DeepSeek | https://api.deepseek.com ,模型 deepseek-v4-flash |
| 阿里云百炼 | https://dashscope.aliyuncs.com/compatible-mode/v1 |
| SiliconFlow | https://api.siliconflow.cn/v1 |

## 构建

```bash
flutter build apk --release
# 测试版(带演示模式)
flutter build apk --release --dart-define=DEMO_MODE=true
```

## 致谢

学习机制(掌握度计算、知识类型分级、间隔复习调度)参考自