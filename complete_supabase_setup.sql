-- ============================================================================
-- Raphael Starterkit v1 - Complete Supabase Database Setup
-- 完整的数据库设置脚本，适用于 Supabase SQL 编辑器
-- ============================================================================

-- 启用必要的扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- 1. 核心表结构创建
-- ============================================================================

-- 创建customers表 - 连接Supabase用户与Creem客户
CREATE TABLE IF NOT EXISTS public.customers (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE, -- 添加UNIQUE约束
    creem_customer_id text NOT NULL UNIQUE,
    email text NOT NULL,
    name text,
    country text,
    credits integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    migration_status text DEFAULT 'native',
    CONSTRAINT customers_email_match CHECK (email = lower(email)),
    CONSTRAINT credits_non_negative CHECK (credits >= 0)
);

-- 创建credits_history表 - 追踪积分交易
CREATE TABLE IF NOT EXISTS public.credits_history (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id uuid REFERENCES public.customers(id) ON DELETE CASCADE NOT NULL,
    amount integer NOT NULL,
    type text NOT NULL CHECK (type IN ('add', 'subtract')),
    description text,
    creem_order_id text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb
);

-- 创建subscriptions表 - 订阅管理
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id uuid REFERENCES public.customers(id) ON DELETE CASCADE NOT NULL,
    creem_subscription_id text NOT NULL UNIQUE,
    creem_product_id text NOT NULL,
    status text NOT NULL CHECK (status IN ('incomplete', 'expired', 'active', 'past_due', 'canceled', 'unpaid', 'paused', 'trialing')),
    current_period_start timestamp with time zone NOT NULL,
    current_period_end timestamp with time zone NOT NULL,
    canceled_at timestamp with time zone,
    trial_end timestamp with time zone,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ============================================================================
-- 2. 中文名字生成相关表
-- ============================================================================

-- 名字生成日志表
CREATE TABLE IF NOT EXISTS public.name_generation_logs (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    plan_type text NOT NULL CHECK (plan_type IN ('1', '4')),
    credits_used integer NOT NULL DEFAULT 1,
    names_generated integer NOT NULL DEFAULT 1,
    english_name text NOT NULL,
    gender text NOT NULL CHECK (gender IN ('male', 'female', 'other')),
    birth_year text,
    has_personality_traits boolean DEFAULT false,
    has_name_preferences boolean DEFAULT false,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 保存的名字表
CREATE TABLE IF NOT EXISTS public.saved_names (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    chinese_name text NOT NULL,
    pinyin text NOT NULL,
    meaning text NOT NULL,
    cultural_notes text,
    personality_match text,
    characters jsonb NOT NULL,
    generation_metadata jsonb DEFAULT '{}'::jsonb,
    is_selected boolean DEFAULT false,
    is_favorite boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 热门名字表
CREATE TABLE IF NOT EXISTS public.popular_names (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    chinese_name text NOT NULL UNIQUE,
    pinyin text NOT NULL,
    meaning text NOT NULL,
    cultural_significance text NOT NULL,
    gender text NOT NULL CHECK (gender IN ('male', 'female', 'unisex')),
    popularity_score integer DEFAULT 0,
    times_generated integer DEFAULT 0,
    times_favorited integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 生成批次表
CREATE TABLE IF NOT EXISTS public.generation_batches (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    english_name text NOT NULL,
    gender text NOT NULL CHECK (gender IN ('male', 'female', 'other')),
    birth_year text,
    personality_traits text,
    name_preferences text,
    plan_type text NOT NULL CHECK (plan_type IN ('1', '4')),
    credits_used integer NOT NULL DEFAULT 0,
    names_count integer NOT NULL DEFAULT 0,
    generation_metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 生成的名字表
CREATE TABLE IF NOT EXISTS public.generated_names (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    batch_id uuid REFERENCES public.generation_batches(id) ON DELETE CASCADE NOT NULL,
    chinese_name text NOT NULL,
    pinyin text NOT NULL,
    characters jsonb NOT NULL,
    meaning text NOT NULL,
    cultural_notes text NOT NULL,
    personality_match text NOT NULL,
    style text NOT NULL,
    position_in_batch integer NOT NULL,
    generation_round integer NOT NULL DEFAULT 1,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT check_generation_round_positive CHECK (generation_round > 0)
);

-- ============================================================================
-- 3. IP限制表
-- ============================================================================

-- IP使用记录表
CREATE TABLE IF NOT EXISTS public.ip_usage_logs (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_ip text NOT NULL,
    usage_date date NOT NULL DEFAULT CURRENT_DATE,
    generation_count integer DEFAULT 0 NOT NULL,
    last_generation_at timestamp with time zone DEFAULT NOW(),
    created_at timestamp with time zone DEFAULT NOW() NOT NULL,
    updated_at timestamp with time zone DEFAULT NOW() NOT NULL,
    CONSTRAINT unique_ip_date UNIQUE (client_ip, usage_date)
);

-- ============================================================================
-- 4. 兼容性表 (如果需要迁移旧数据)
-- ============================================================================

-- 旧的用户积分表结构
CREATE TABLE IF NOT EXISTS public.user_credits (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    total_credits integer DEFAULT 0 NOT NULL,
    remaining_credits integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 旧的积分交易表结构
CREATE TABLE IF NOT EXISTS public.credit_transactions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    amount integer NOT NULL,
    transaction_type text NOT NULL,
    operation text DEFAULT 'name_generation',
    remaining_credits integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ============================================================================
-- 5. 创建索引
-- ============================================================================

-- customers表索引
CREATE INDEX IF NOT EXISTS customers_user_id_idx ON public.customers(user_id);
CREATE INDEX IF NOT EXISTS customers_creem_customer_id_idx ON public.customers(creem_customer_id);

-- credits_history表索引
CREATE INDEX IF NOT EXISTS credits_history_customer_id_idx ON public.credits_history(customer_id);
CREATE INDEX IF NOT EXISTS credits_history_created_at_idx ON public.credits_history(created_at);

-- subscriptions表索引
CREATE INDEX IF NOT EXISTS subscriptions_customer_id_idx ON public.subscriptions(customer_id);
CREATE INDEX IF NOT EXISTS subscriptions_status_idx ON public.subscriptions(status);

-- name_generation_logs表索引
CREATE INDEX IF NOT EXISTS name_generation_logs_user_id_idx ON public.name_generation_logs(user_id);
CREATE INDEX IF NOT EXISTS name_generation_logs_created_at_idx ON public.name_generation_logs(created_at);
CREATE INDEX IF NOT EXISTS name_generation_logs_plan_type_idx ON public.name_generation_logs(plan_type);

-- saved_names表索引
CREATE INDEX IF NOT EXISTS saved_names_user_id_idx ON public.saved_names(user_id);
CREATE INDEX IF NOT EXISTS saved_names_is_selected_idx ON public.saved_names(is_selected);
CREATE INDEX IF NOT EXISTS saved_names_is_favorite_idx ON public.saved_names(is_favorite);
CREATE INDEX IF NOT EXISTS saved_names_chinese_name_idx ON public.saved_names(chinese_name);

-- popular_names表索引
CREATE INDEX IF NOT EXISTS popular_names_popularity_score_idx ON public.popular_names(popularity_score DESC);
CREATE INDEX IF NOT EXISTS popular_names_gender_idx ON public.popular_names(gender);
CREATE INDEX IF NOT EXISTS popular_names_times_generated_idx ON public.popular_names(times_generated DESC);

-- generation_batches表索引
CREATE INDEX IF NOT EXISTS generation_batches_user_id_idx ON public.generation_batches(user_id);
CREATE INDEX IF NOT EXISTS generation_batches_created_at_idx ON public.generation_batches(created_at);
CREATE INDEX IF NOT EXISTS generation_batches_plan_type_idx ON public.generation_batches(plan_type);
CREATE INDEX IF NOT EXISTS idx_generation_batches_user_created ON public.generation_batches(user_id, created_at DESC);

-- generated_names表索引
CREATE INDEX IF NOT EXISTS generated_names_batch_id_idx ON public.generated_names(batch_id);
CREATE INDEX IF NOT EXISTS generated_names_position_idx ON public.generated_names(position_in_batch);
CREATE INDEX IF NOT EXISTS generated_names_chinese_name_idx ON public.generated_names(chinese_name);
CREATE INDEX IF NOT EXISTS generated_names_round_idx ON public.generated_names(generation_round);
CREATE INDEX IF NOT EXISTS generated_names_batch_round_idx ON public.generated_names(batch_id, generation_round);
CREATE INDEX IF NOT EXISTS idx_generated_names_batch_id_round ON public.generated_names(batch_id, generation_round);

-- ip_usage_logs表索引
CREATE INDEX IF NOT EXISTS ip_usage_logs_client_ip_idx ON public.ip_usage_logs(client_ip);
CREATE INDEX IF NOT EXISTS ip_usage_logs_usage_date_idx ON public.ip_usage_logs(usage_date);
CREATE INDEX IF NOT EXISTS ip_usage_logs_created_at_idx ON public.ip_usage_logs(created_at);

-- 兼容性表索引
CREATE INDEX IF NOT EXISTS user_credits_user_id_idx ON public.user_credits(user_id);
CREATE INDEX IF NOT EXISTS credit_transactions_user_id_idx ON public.credit_transactions(user_id);
CREATE INDEX IF NOT EXISTS credit_transactions_created_at_idx ON public.credit_transactions(created_at);

-- ============================================================================
-- 6. 创建函数
-- ============================================================================

-- 更新时间触发器函数
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS trigger AS $$
BEGIN
    new.updated_at = timezone('utc'::text, now());
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 兼容的更新时间函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

-- 自动创建customer记录的函数
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.customers (
    user_id,
    email,
    credits,
    creem_customer_id,
    created_at,
    updated_at,
    metadata
  ) VALUES (
    NEW.id,
    NEW.email,
    3, -- 新用户赠送3积分
    'auto_' || NEW.id::text,
    NOW(),
    NOW(),
    jsonb_build_object(
      'source', 'auto_registration',
      'initial_credits', 3,
      'registration_date', NOW()
    )
  );

  INSERT INTO public.credits_history (
    customer_id,
    amount,
    type,
    description,
    created_at,
    metadata
  ) VALUES (
    (SELECT id FROM public.customers WHERE user_id = NEW.id),
    3,
    'add',
    'Welcome bonus for new user registration',
    NOW(),
    jsonb_build_object(
      'source', 'welcome_bonus',
      'user_registration', true
    )
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- IP限制检查函数
CREATE OR REPLACE FUNCTION public.check_ip_rate_limit(p_client_ip text)
RETURNS boolean AS $$
DECLARE
    current_count integer := 0;
    daily_limit integer := 1; -- 每天1次免费生成
BEGIN
    SELECT COALESCE(ipl.generation_count, 0) INTO current_count
    FROM public.ip_usage_logs ipl
    WHERE ipl.client_ip = p_client_ip
    AND ipl.usage_date = CURRENT_DATE;
    
    IF current_count IS NULL THEN
        current_count := 0;
    END IF;
    
    IF current_count >= daily_limit THEN
        RETURN false; -- 已达到限制
    ELSE
        INSERT INTO public.ip_usage_logs (
            client_ip,
            usage_date,
            generation_count,
            last_generation_at,
            updated_at
        ) VALUES (
            p_client_ip,
            CURRENT_DATE,
            1,
            NOW(),
            NOW()
        )
        ON CONFLICT (client_ip, usage_date)
        DO UPDATE SET
            generation_count = ip_usage_logs.generation_count + 1,
            last_generation_at = NOW(),
            updated_at = NOW();
            
        RETURN true; -- 可以生成
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- IP使用统计查看函数
CREATE OR REPLACE FUNCTION public.get_ip_usage_stats(days_back integer DEFAULT 7)
RETURNS TABLE (
    client_ip text,
    usage_date date,
    generation_count integer,
    last_generation_at timestamp with time zone
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ipl.client_ip,
        ipl.usage_date,
        ipl.generation_count,
        ipl.last_generation_at
    FROM public.ip_usage_logs ipl
    WHERE ipl.usage_date >= CURRENT_DATE - days_back
    ORDER BY ipl.usage_date DESC, ipl.generation_count DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 清理旧IP记录函数
CREATE OR REPLACE FUNCTION public.cleanup_old_ip_logs(days_to_keep integer DEFAULT 30)
RETURNS integer AS $$
DECLARE
    deleted_count integer;
BEGIN
    DELETE FROM public.ip_usage_logs
    WHERE usage_date < CURRENT_DATE - days_to_keep;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    RAISE NOTICE 'Cleaned up % old IP usage records older than % days', deleted_count, days_to_keep;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 更新热门名字统计函数
CREATE OR REPLACE FUNCTION public.update_popular_name_stats(name_text text, action_type text)
RETURNS void AS $$
BEGIN
    IF action_type = 'generated' THEN
        INSERT INTO public.popular_names 
        (chinese_name, pinyin, meaning, cultural_significance, gender, times_generated, popularity_score)
        VALUES (name_text, '', 'AI generated name', 'Modern AI-generated Chinese name', 'unisex', 1, 1)
        ON CONFLICT (chinese_name) 
        DO UPDATE SET 
            times_generated = public.popular_names.times_generated + 1,
            popularity_score = public.popular_names.popularity_score + 1,
            updated_at = timezone('utc'::text, now());
    ELSIF action_type = 'favorited' THEN
        UPDATE public.popular_names 
        SET 
            times_favorited = times_favorited + 1,
            popularity_score = popularity_score + 2,
            updated_at = timezone('utc'::text, now())
        WHERE chinese_name = name_text;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 数据迁移函数
CREATE OR REPLACE FUNCTION migrate_chinesename_credits()
RETURNS void AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'user_credits'
    ) THEN
        INSERT INTO public.customers (
            user_id, 
            email, 
            credits, 
            creem_customer_id,
            created_at, 
            updated_at,
            metadata
        )
        SELECT 
            uc.user_id,
            COALESCE(au.email, 'unknown@example.com'),
            COALESCE(uc.remaining_credits, 0),
            'migrated_' || uc.user_id::text,
            uc.created_at,
            uc.updated_at,
            jsonb_build_object(
                'migrated_from', 'chinesename',
                'original_total_credits', uc.total_credits,
                'migration_date', now()
            )
        FROM user_credits uc
        LEFT JOIN auth.users au ON uc.user_id = au.id
        ON CONFLICT (user_id) DO UPDATE SET
            credits = EXCLUDED.credits,
            updated_at = EXCLUDED.updated_at,
            metadata = customers.metadata || EXCLUDED.metadata;

        RAISE NOTICE 'Migrated % user credit records', (SELECT COUNT(*) FROM user_credits);
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'credit_transactions'
    ) THEN
        INSERT INTO public.credits_history (
            customer_id,
            amount,
            type,
            description,
            created_at,
            metadata
        )
        SELECT 
            c.id,
            ABS(ct.amount),
            CASE 
                WHEN ct.amount < 0 OR ct.transaction_type = 'spend' THEN 'subtract'
                ELSE 'add'
            END,
            COALESCE(ct.operation, 'migrated_transaction'),
            ct.created_at,
            jsonb_build_object(
                'migrated_from', 'chinesename',
                'original_transaction_type', ct.transaction_type,
                'original_amount', ct.amount,
                'remaining_credits_at_time', ct.remaining_credits
            )
        FROM credit_transactions ct
        INNER JOIN customers c ON ct.user_id = c.user_id
        ON CONFLICT DO NOTHING;

        RAISE NOTICE 'Migrated % credit transaction records', (SELECT COUNT(*) FROM credit_transactions);
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 7. 创建触发器
-- ============================================================================

-- 更新时间触发器
DROP TRIGGER IF EXISTS handle_customers_updated_at ON public.customers;
CREATE TRIGGER handle_customers_updated_at
    BEFORE UPDATE ON public.customers
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS handle_subscriptions_updated_at ON public.subscriptions;
CREATE TRIGGER handle_subscriptions_updated_at
    BEFORE UPDATE ON public.subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS handle_saved_names_updated_at ON public.saved_names;
CREATE TRIGGER handle_saved_names_updated_at
    BEFORE UPDATE ON public.saved_names
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS handle_popular_names_updated_at ON public.popular_names;
CREATE TRIGGER handle_popular_names_updated_at
    BEFORE UPDATE ON public.popular_names
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS handle_generation_batches_updated_at ON public.generation_batches;
CREATE TRIGGER handle_generation_batches_updated_at
    BEFORE UPDATE ON public.generation_batches
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS handle_generated_names_updated_at ON public.generated_names;
CREATE TRIGGER handle_generated_names_updated_at
    BEFORE UPDATE ON public.generated_names
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS handle_ip_usage_logs_updated_at ON public.ip_usage_logs;
CREATE TRIGGER handle_ip_usage_logs_updated_at
    BEFORE UPDATE ON public.ip_usage_logs
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- 新用户自动创建customer记录触发器
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- 8. 启用RLS (Row Level Security)
-- ============================================================================

ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credits_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.name_generation_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_names ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.popular_names ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.generation_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.generated_names ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ip_usage_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_credits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credit_transactions ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 9. 创建RLS策略
-- ============================================================================

-- customers表策略
DROP POLICY IF EXISTS "Users can view their own customer data" ON public.customers;
CREATE POLICY "Users can view their own customer data"
    ON public.customers FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own customer data" ON public.customers;
CREATE POLICY "Users can update their own customer data"
    ON public.customers FOR UPDATE
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role can manage customer data" ON public.customers;
CREATE POLICY "Service role can manage customer data"
    ON public.customers FOR ALL
    USING (auth.role() = 'service_role');

-- credits_history表策略
DROP POLICY IF EXISTS "Users can view their own credits history" ON public.credits_history;
CREATE POLICY "Users can view their own credits history"
    ON public.credits_history FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.customers
            WHERE customers.id = credits_history.customer_id
            AND customers.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Service role can manage credits history" ON public.credits_history;
CREATE POLICY "Service role can manage credits history"
    ON public.credits_history FOR ALL
    USING (auth.role() = 'service_role');

-- subscriptions表策略
DROP POLICY IF EXISTS "Users can view their own subscriptions" ON public.subscriptions;
CREATE POLICY "Users can view their own subscriptions"
    ON public.subscriptions FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.customers
            WHERE customers.id = subscriptions.customer_id
            AND customers.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Service role can manage subscriptions" ON public.subscriptions;
CREATE POLICY "Service role can manage subscriptions"
    ON public.subscriptions FOR ALL
    USING (auth.role() = 'service_role');

-- name_generation_logs表策略
DROP POLICY IF EXISTS "Users can view their own name generation logs" ON public.name_generation_logs;
CREATE POLICY "Users can view their own name generation logs"
    ON public.name_generation_logs FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role can manage name generation logs" ON public.name_generation_logs;
CREATE POLICY "Service role can manage name generation logs"
    ON public.name_generation_logs FOR ALL
    USING (auth.role() = 'service_role');

-- saved_names表策略
DROP POLICY IF EXISTS "Users can view their own saved names" ON public.saved_names;
CREATE POLICY "Users can view their own saved names"
    ON public.saved_names FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own saved names" ON public.saved_names;
CREATE POLICY "Users can insert their own saved names"
    ON public.saved_names FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own saved names" ON public.saved_names;
CREATE POLICY "Users can update their own saved names"
    ON public.saved_names FOR UPDATE
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own saved names" ON public.saved_names;
CREATE POLICY "Users can delete their own saved names"
    ON public.saved_names FOR DELETE
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role can manage saved names" ON public.saved_names;
CREATE POLICY "Service role can manage saved names"
    ON public.saved_names FOR ALL
    USING (auth.role() = 'service_role');

-- popular_names表策略
DROP POLICY IF EXISTS "Anyone can view popular names" ON public.popular_names;
CREATE POLICY "Anyone can view popular names"
    ON public.popular_names FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "Service role can manage popular names" ON public.popular_names;
CREATE POLICY "Service role can manage popular names"
    ON public.popular_names FOR ALL
    USING (auth.role() = 'service_role');

-- generation_batches表策略
DROP POLICY IF EXISTS "Users can view their own generation batches" ON public.generation_batches;
CREATE POLICY "Users can view their own generation batches"
    ON public.generation_batches FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own generation batches" ON public.generation_batches;
CREATE POLICY "Users can insert their own generation batches"
    ON public.generation_batches FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own generation batches" ON public.generation_batches;
CREATE POLICY "Users can update their own generation batches"
    ON public.generation_batches FOR UPDATE
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own generation batches" ON public.generation_batches;
CREATE POLICY "Users can delete their own generation batches"
    ON public.generation_batches FOR DELETE
    USING (auth.uid() = user_id);

-- generated_names表策略
DROP POLICY IF EXISTS "Users can view names from their own batches" ON public.generated_names;
CREATE POLICY "Users can view names from their own batches"
    ON public.generated_names FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.generation_batches 
            WHERE id = generated_names.batch_id 
            AND user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can insert names to their own batches" ON public.generated_names;
CREATE POLICY "Users can insert names to their own batches"
    ON public.generated_names FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.generation_batches 
            WHERE id = generated_names.batch_id 
            AND user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can update names in their own batches" ON public.generated_names;
CREATE POLICY "Users can update names in their own batches"
    ON public.generated_names FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.generation_batches 
            WHERE id = generated_names.batch_id 
            AND user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can delete names from their own batches" ON public.generated_names;
CREATE POLICY "Users can delete names from their own batches"
    ON public.generated_names FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.generation_batches 
            WHERE id = generated_names.batch_id 
            AND user_id = auth.uid()
        )
    );

-- ip_usage_logs表策略
DROP POLICY IF EXISTS "Service role can manage IP usage logs" ON public.ip_usage_logs;
CREATE POLICY "Service role can manage IP usage logs"
    ON public.ip_usage_logs FOR ALL
    USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Admins can view IP usage stats" ON public.ip_usage_logs;
CREATE POLICY "Admins can view IP usage stats"
    ON public.ip_usage_logs FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.customers c
            WHERE c.user_id = auth.uid()
            AND c.metadata->>'role' = 'admin'
        )
    );

-- 兼容性表策略
DROP POLICY IF EXISTS "Users can view their own credits" ON public.user_credits;
CREATE POLICY "Users can view their own credits" 
ON public.user_credits FOR SELECT 
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role can manage user credits" ON public.user_credits;
CREATE POLICY "Service role can manage user credits" 
ON public.user_credits FOR ALL 
USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Users can view their own transactions" ON public.credit_transactions;
CREATE POLICY "Users can view their own transactions" 
ON public.credit_transactions FOR SELECT 
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role can manage credit transactions" ON public.credit_transactions;
CREATE POLICY "Service role can manage credit transactions" 
ON public.credit_transactions FOR ALL 
USING (auth.role() = 'service_role');


-- ============================================================================
-- 12. 创建兼容性视图
-- ============================================================================

-- 创建向后兼容的视图
CREATE OR REPLACE VIEW public.user_credits_compat AS
SELECT 
    gen_random_uuid() as id,
    user_id,
    credits as total_credits,
    credits as remaining_credits,
    created_at,
    updated_at
FROM public.customers
WHERE migration_status = 'migrated_from_chinesename';

-- ============================================================================
-- 10. 授予权限
-- ============================================================================

-- 核心表权限
GRANT ALL ON public.customers TO service_role;
GRANT ALL ON public.subscriptions TO service_role;
GRANT ALL ON public.credits_history TO service_role;

-- 中文名字相关表权限
GRANT ALL ON public.name_generation_logs TO service_role;
GRANT ALL ON public.saved_names TO service_role;
GRANT ALL ON public.popular_names TO service_role;
GRANT ALL ON public.generation_batches TO service_role;
GRANT ALL ON public.generated_names TO service_role;

-- 生成批次表特殊权限
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON public.generation_batches TO authenticated;
GRANT ALL ON public.generated_names TO authenticated;

-- IP限制表权限
GRANT ALL ON public.ip_usage_logs TO service_role;

-- 兼容性表权限
GRANT ALL ON public.user_credits TO service_role;
GRANT ALL ON public.credit_transactions TO service_role;

-- 函数权限
GRANT EXECUTE ON FUNCTION public.check_ip_rate_limit(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_ip_usage_stats(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.cleanup_old_ip_logs(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.update_popular_name_stats(text, text) TO service_role;

-- 兼容性视图权限
GRANT SELECT ON public.user_credits_compat TO authenticated;

-- ============================================================================
-- 11. 插入示例数据
-- ============================================================================

-- 插入热门名字示例数据
INSERT INTO public.popular_names 
(chinese_name, pinyin, meaning, cultural_significance, gender, popularity_score, times_generated, times_favorited) 
VALUES 
('李雨桐', 'Lǐ Yǔtóng', 'Rain and paulownia tree - symbolizing grace and growth', 'A name that represents natural beauty and strength', 'female', 95, 150, 45),
('王志明', 'Wáng Zhìmíng', 'Bright ambition - representing wisdom and determination', 'Classic name embodying traditional values of wisdom and aspiration', 'male', 92, 142, 38),
('陈美丽', 'Chén Měilì', 'Beautiful and graceful - representing inner and outer beauty', 'Timeless name celebrating feminine grace and beauty', 'female', 88, 130, 35),
('张伟强', 'Zhāng Wěiqiáng', 'Great strength - symbolizing power and resilience', 'Name reflecting strength of character and leadership qualities', 'male', 87, 125, 32),
('刘慧敏', 'Liú Huìmǐn', 'Wise and quick-minded - representing intelligence and agility', 'Name celebrating intellectual prowess and sharp thinking', 'female', 85, 118, 28),
('黄文昊', 'Huáng Wénhào', 'Literary and vast - representing scholarly achievement', 'Name honoring academic excellence and broad knowledge', 'male', 83, 112, 25),
('林雅静', 'Lín Yǎjìng', 'Elegant and tranquil - representing refined peace', 'A name that embodies serenity and sophistication', 'female', 81, 105, 22),
('周建国', 'Zhōu Jiànguó', 'Building the nation - representing patriotic spirit', 'Name reflecting dedication to country and community service', 'male', 79, 98, 20)
ON CONFLICT (chinese_name) DO NOTHING;



-- ============================================================================
-- 13. 数据修复和迁移
-- ============================================================================

-- 执行数据迁移（如果有旧数据）
SELECT migrate_chinesename_credits();

-- 为现有用户创建customer记录
INSERT INTO public.customers (
  user_id,
  email,
  credits,
  creem_customer_id,
  created_at,
  updated_at,
  metadata
)
SELECT 
  au.id,
  au.email,
  3, -- 赠送3积分
  'existing_' || au.id::text,
  au.created_at,
  NOW(),
  jsonb_build_object(
    'source', 'existing_user_migration',
    'initial_credits', 3,
    'migration_date', NOW()
  )
FROM auth.users au
LEFT JOIN public.customers c ON au.id = c.user_id
WHERE c.user_id IS NULL
ON CONFLICT DO NOTHING;

-- 为现有用户添加初始积分历史记录
INSERT INTO public.credits_history (
  customer_id,
  amount,
  type,
  description,
  created_at,
  metadata
)
SELECT 
  c.id,
  3,
  'add',
  'Welcome bonus for existing user',
  NOW(),
  jsonb_build_object(
    'source', 'existing_user_bonus',
    'migration', true
  )
FROM public.customers c
LEFT JOIN public.credits_history ch ON c.id = ch.customer_id
WHERE ch.customer_id IS NULL
AND c.creem_customer_id LIKE 'existing_%'
ON CONFLICT DO NOTHING;

-- 修复generation_round数据
UPDATE public.generated_names 
SET generation_round = 1 
WHERE generation_round IS NULL OR generation_round = 0 OR generation_round < 1;

-- 更新批次的names_count
UPDATE public.generation_batches 
SET names_count = (
  SELECT COUNT(*) 
  FROM public.generated_names 
  WHERE generated_names.batch_id = generation_batches.id
)
WHERE names_count IS NULL OR names_count = 0;

-- ============================================================================
-- 14. 完成提示
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'Raphael Starterkit v1 数据库设置完成！';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE '✅ 核心表已创建: customers, credits_history, subscriptions';
    RAISE NOTICE '✅ 中文名字相关表已创建: name_generation_logs, saved_names, popular_names';
    RAISE NOTICE '✅ 生成批次表已创建: generation_batches, generated_names';
    RAISE NOTICE '✅ IP限制表已创建: ip_usage_logs';
    RAISE NOTICE '✅ 所有索引已创建';
    RAISE NOTICE '✅ 所有函数已创建';
    RAISE NOTICE '✅ 所有触发器已创建';
    RAISE NOTICE '✅ RLS安全策略已启用';
    RAISE NOTICE '✅ 权限已正确设置';
    RAISE NOTICE '✅ 示例数据已插入';
    RAISE NOTICE '✅ 现有用户已获得3积分';
    RAISE NOTICE '✅ 新用户注册将自动获得3积分';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE '数据库已准备就绪，可以开始使用！';
    RAISE NOTICE '============================================================================';
END $$;
