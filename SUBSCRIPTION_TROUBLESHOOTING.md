# 🔧 订阅系统故障排除指南

## 🚀 快速诊断

### 1. 运行诊断API
访问你的部署域名：`https://your-domain.vercel.app/api/debug/subscription`

这会显示：
- ✅ 环境变量配置状态
- ✅ 用户和客户记录状态  
- ✅ 订阅和积分历史
- ✅ Creem API连接测试

### 2. 检查环境变量
运行环境检查脚本：
```bash
node scripts/check-env.js
```

---

## 🔍 常见问题和解决方案

### 问题 1: 环境变量未设置
**症状**: 订阅创建失败，API返回500错误

**解决方案**:
1. 登录 [Vercel Dashboard](https://vercel.com/dashboard)
2. 选择你的项目
3. 进入 `Settings` > `Environment Variables`
4. 添加以下必需变量：

```bash
# Supabase 配置
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Creem 配置
CREEM_API_KEY=your_creem_api_key
CREEM_API_URL=https://api.creem.com/v1
CREEM_WEBHOOK_SECRET=your_webhook_secret

# 站点配置
NEXT_PUBLIC_SITE_URL=https://your-domain.vercel.app
CREEM_SUCCESS_URL=https://your-domain.vercel.app/dashboard
```

5. 重新部署项目

### 问题 2: Webhook签名验证失败
**症状**: Webhook返回401 "Invalid signature"

**解决方案**:
1. 检查 `CREEM_WEBHOOK_SECRET` 是否正确设置
2. 确保Creem后台的webhook URL正确：
   ```
   https://your-domain.vercel.app/api/webhooks/creem
   ```
3. 检查Vercel函数日志：
   - 进入Vercel Dashboard
   - 选择项目 > Functions 
   - 查看 `/api/webhooks/creem` 的日志

### 问题 3: 客户记录冲突
**症状**: 数据库错误 "duplicate key value violates unique constraint"

**解决方案**:
已在代码中修复，现在会：
1. 首先检查Creem客户ID是否存在
2. 如果不存在，检查用户是否已有客户记录
3. 更新现有记录而不是创建新记录

### 问题 4: 订阅状态不同步
**症状**: 用户支付成功但订阅状态未更新

**调试步骤**:
1. 检查Vercel函数日志
2. 访问诊断API查看数据库状态
3. 检查Creem后台的webhook发送状态

---

## 🛠️ 调试工具

### 1. 诊断API
```bash
curl https://your-domain.vercel.app/api/debug/subscription \
  -H "Authorization: Bearer YOUR_USER_JWT"
```

### 2. 检查Webhook日志
在Vercel Dashboard中查看函数日志：
- 进入项目
- 点击 `Functions` 标签
- 选择 `api/webhooks/creem`
- 查看最近的调用日志

### 3. 数据库查询
使用Supabase Dashboard直接查询：

```sql
-- 检查客户记录
SELECT * FROM customers WHERE user_id = 'your-user-id';

-- 检查订阅状态
SELECT * FROM subscriptions 
JOIN customers ON subscriptions.customer_id = customers.id 
WHERE customers.user_id = 'your-user-id';

-- 检查积分历史
SELECT * FROM credits_history 
JOIN customers ON credits_history.customer_id = customers.id 
WHERE customers.user_id = 'your-user-id'
ORDER BY created_at DESC;
```

---

## 🔄 测试流程

### 1. 本地测试
```bash
# 1. 检查环境变量
node scripts/check-env.js

# 2. 启动开发服务器
npm run dev

# 3. 测试订阅流程
# 访问 http://localhost:3000 并尝试购买
```

### 2. 生产测试
1. 部署到Vercel
2. 访问诊断API
3. 尝试测试购买
4. 检查Vercel日志

---

## 📞 获取帮助

如果问题仍然存在：

1. **收集信息**：
   - 诊断API的完整输出
   - Vercel函数日志截图
   - 错误消息的完整文本

2. **检查配置**：
   - Creem后台配置
   - Supabase RLS策略
   - 环境变量设置

3. **常见解决方案**：
   - 重新部署项目
   - 清除浏览器缓存
   - 检查网络连接

---

## ⚡ 快速修复清单

- [ ] 所有环境变量已设置
- [ ] Webhook URL配置正确
- [ ] Supabase数据库已设置
- [ ] RLS策略已启用
- [ ] 函数日志无错误
- [ ] 诊断API返回正常数据
- [ ] Creem产品ID正确
- [ ] 成功URL配置正确

完成这个清单应该能解决大部分订阅问题。
