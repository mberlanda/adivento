SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: check_market_leg_count(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_market_leg_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF (SELECT COUNT(*) FROM market_legs WHERE market_id = NEW.market_id) >= 2 THEN
    RAISE EXCEPTION 'Market % already has 2 legs', NEW.market_id;
  END IF;
  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_events (
    id bigint NOT NULL,
    action character varying NOT NULL,
    actor_id integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    metadata json DEFAULT '{}'::json NOT NULL,
    reason text,
    target_id bigint NOT NULL,
    target_type character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: audit_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audit_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audit_events_id_seq OWNED BY public.audit_events.id;


--
-- Name: bets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bets (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    fee_minor bigint NOT NULL,
    market_id bigint NOT NULL,
    market_leg_id bigint NOT NULL,
    net_stake_minor bigint NOT NULL,
    odds_minor integer NOT NULL,
    potential_payout_minor bigint NOT NULL,
    stake_minor bigint NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: bets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bets_id_seq OWNED BY public.bets.id;


--
-- Name: betslip_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.betslip_executions (
    id bigint NOT NULL,
    betslip_quote_id bigint NOT NULL,
    user_id bigint NOT NULL,
    bet_ids json DEFAULT '[]'::json NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: betslip_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.betslip_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: betslip_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.betslip_executions_id_seq OWNED BY public.betslip_executions.id;


--
-- Name: betslip_quotes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.betslip_quotes (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    idempotency_key character varying NOT NULL,
    items json DEFAULT '[]'::json NOT NULL,
    total_stake_minor bigint NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: betslip_quotes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.betslip_quotes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: betslip_quotes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.betslip_quotes_id_seq OWNED BY public.betslip_quotes.id;


--
-- Name: faucet_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.faucet_requests (
    id bigint NOT NULL,
    amount_minor bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    note text,
    reviewed_by_id integer,
    status integer DEFAULT 0 NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id integer NOT NULL
);


--
-- Name: faucet_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.faucet_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: faucet_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.faucet_requests_id_seq OWNED BY public.faucet_requests.id;


--
-- Name: ledger_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ledger_entries (
    id bigint NOT NULL,
    actor_id integer NOT NULL,
    amount_minor bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    direction character varying NOT NULL,
    entry_type character varying NOT NULL,
    metadata json DEFAULT '{}'::json NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id integer NOT NULL
);


--
-- Name: ledger_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ledger_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ledger_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ledger_entries_id_seq OWNED BY public.ledger_entries.id;


--
-- Name: market_legs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.market_legs (
    id bigint NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    label character varying NOT NULL,
    market_id integer NOT NULL,
    odds_minor integer DEFAULT 5000 NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: market_legs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.market_legs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: market_legs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.market_legs_id_seq OWNED BY public.market_legs.id;


--
-- Name: market_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.market_templates (
    id bigint NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    default_duration_hours integer DEFAULT 24 NOT NULL,
    default_legs text,
    description text,
    key character varying NOT NULL,
    name character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: market_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.market_templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: market_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.market_templates_id_seq OWNED BY public.market_templates.id;


--
-- Name: markets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.markets (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    created_by_id integer NOT NULL,
    description text NOT NULL,
    fee_bps integer DEFAULT 100 NOT NULL,
    liability_cap_minor bigint DEFAULT 100000 NOT NULL,
    mechanism_type character varying DEFAULT 'fixed_odds'::character varying NOT NULL,
    question character varying NOT NULL,
    settled_by_id integer,
    settled_outcome character varying,
    status integer DEFAULT 0 NOT NULL,
    structure_locked boolean DEFAULT false NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    taker_fee_bps integer,
    liquidity_subsidy_minor bigint,
    spread_fee_bps integer,
    takeout_bps integer,
    lmsr_b_parameter double precision,
    lmsr_q_yes bigint DEFAULT 0 NOT NULL,
    lmsr_q_no bigint DEFAULT 0 NOT NULL,
    parimutuel_pool_yes_minor bigint DEFAULT 0 NOT NULL,
    parimutuel_pool_no_minor bigint DEFAULT 0 NOT NULL,
    last_fill_price_cents integer,
    category character varying DEFAULT 'other'::character varying NOT NULL,
    tags json DEFAULT '[]'::json NOT NULL,
    close_at timestamp(6) without time zone,
    resolution_criteria text,
    resolution_source character varying,
    lmsr_realized_loss_minor bigint DEFAULT 0 NOT NULL,
    CONSTRAINT markets_closed_requires_close_at CHECK (((status <> 4) OR (close_at IS NOT NULL)))
);


--
-- Name: markets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.markets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: markets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.markets_id_seq OWNED BY public.markets.id;


--
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orders (
    id bigint NOT NULL,
    market_id bigint NOT NULL,
    market_leg_id bigint NOT NULL,
    user_id bigint NOT NULL,
    side character varying NOT NULL,
    price_cents integer NOT NULL,
    quantity integer NOT NULL,
    filled_quantity integer DEFAULT 0 NOT NULL,
    cancelled_quantity integer DEFAULT 0 NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    time_in_force integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: orders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.orders_id_seq OWNED BY public.orders.id;


--
-- Name: permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permissions (
    id bigint NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    description character varying,
    key character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.permissions_id_seq OWNED BY public.permissions.id;


--
-- Name: price_snapshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.price_snapshots (
    id bigint NOT NULL,
    market_id bigint NOT NULL,
    mechanism_type character varying NOT NULL,
    snapshot_data json DEFAULT '{}'::json NOT NULL,
    recorded_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: price_snapshots_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.price_snapshots_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: price_snapshots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.price_snapshots_id_seq OWNED BY public.price_snapshots.id;


--
-- Name: role_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role_permissions (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    permission_id bigint NOT NULL,
    role_name character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: role_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.role_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: role_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.role_permissions_id_seq OWNED BY public.role_permissions.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: user_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_grants (
    id bigint NOT NULL,
    allow boolean NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    expires_at timestamp(6) without time zone,
    granted_by_id bigint NOT NULL,
    permission_id bigint NOT NULL,
    reason text,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: user_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_grants_id_seq OWNED BY public.user_grants.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    email character varying NOT NULL,
    password_digest character varying NOT NULL,
    role integer DEFAULT 2 NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: wallets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wallets (
    id bigint NOT NULL,
    asset_code character varying DEFAULT 'ADIV'::character varying NOT NULL,
    available_minor bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    reserved_minor bigint DEFAULT 0 NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id integer NOT NULL
);


--
-- Name: wallets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.wallets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: wallets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.wallets_id_seq OWNED BY public.wallets.id;


--
-- Name: audit_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events ALTER COLUMN id SET DEFAULT nextval('public.audit_events_id_seq'::regclass);


--
-- Name: bets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bets ALTER COLUMN id SET DEFAULT nextval('public.bets_id_seq'::regclass);


--
-- Name: betslip_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.betslip_executions ALTER COLUMN id SET DEFAULT nextval('public.betslip_executions_id_seq'::regclass);


--
-- Name: betslip_quotes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.betslip_quotes ALTER COLUMN id SET DEFAULT nextval('public.betslip_quotes_id_seq'::regclass);


--
-- Name: faucet_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.faucet_requests ALTER COLUMN id SET DEFAULT nextval('public.faucet_requests_id_seq'::regclass);


--
-- Name: ledger_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger_entries ALTER COLUMN id SET DEFAULT nextval('public.ledger_entries_id_seq'::regclass);


--
-- Name: market_legs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_legs ALTER COLUMN id SET DEFAULT nextval('public.market_legs_id_seq'::regclass);


--
-- Name: market_templates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_templates ALTER COLUMN id SET DEFAULT nextval('public.market_templates_id_seq'::regclass);


--
-- Name: markets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.markets ALTER COLUMN id SET DEFAULT nextval('public.markets_id_seq'::regclass);


--
-- Name: orders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders ALTER COLUMN id SET DEFAULT nextval('public.orders_id_seq'::regclass);


--
-- Name: permissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions ALTER COLUMN id SET DEFAULT nextval('public.permissions_id_seq'::regclass);


--
-- Name: price_snapshots id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_snapshots ALTER COLUMN id SET DEFAULT nextval('public.price_snapshots_id_seq'::regclass);


--
-- Name: role_permissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions ALTER COLUMN id SET DEFAULT nextval('public.role_permissions_id_seq'::regclass);


--
-- Name: user_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_grants ALTER COLUMN id SET DEFAULT nextval('public.user_grants_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: wallets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallets ALTER COLUMN id SET DEFAULT nextval('public.wallets_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: audit_events audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_pkey PRIMARY KEY (id);


--
-- Name: bets bets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bets
    ADD CONSTRAINT bets_pkey PRIMARY KEY (id);


--
-- Name: betslip_executions betslip_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.betslip_executions
    ADD CONSTRAINT betslip_executions_pkey PRIMARY KEY (id);


--
-- Name: betslip_quotes betslip_quotes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.betslip_quotes
    ADD CONSTRAINT betslip_quotes_pkey PRIMARY KEY (id);


--
-- Name: faucet_requests faucet_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.faucet_requests
    ADD CONSTRAINT faucet_requests_pkey PRIMARY KEY (id);


--
-- Name: ledger_entries ledger_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger_entries
    ADD CONSTRAINT ledger_entries_pkey PRIMARY KEY (id);


--
-- Name: market_legs market_legs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_legs
    ADD CONSTRAINT market_legs_pkey PRIMARY KEY (id);


--
-- Name: market_templates market_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_templates
    ADD CONSTRAINT market_templates_pkey PRIMARY KEY (id);


--
-- Name: markets markets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.markets
    ADD CONSTRAINT markets_pkey PRIMARY KEY (id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- Name: price_snapshots price_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_snapshots
    ADD CONSTRAINT price_snapshots_pkey PRIMARY KEY (id);


--
-- Name: role_permissions role_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: user_grants user_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_grants
    ADD CONSTRAINT user_grants_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: wallets wallets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallets
    ADD CONSTRAINT wallets_pkey PRIMARY KEY (id);


--
-- Name: index_audit_events_on_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_action ON public.audit_events USING btree (action);


--
-- Name: index_audit_events_on_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_actor_id ON public.audit_events USING btree (actor_id);


--
-- Name: index_audit_events_on_target_type_and_target_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_target_type_and_target_id ON public.audit_events USING btree (target_type, target_id);


--
-- Name: index_bets_on_market_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bets_on_market_id ON public.bets USING btree (market_id);


--
-- Name: index_bets_on_market_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bets_on_market_id_and_status ON public.bets USING btree (market_id, status);


--
-- Name: index_bets_on_market_leg_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bets_on_market_leg_id ON public.bets USING btree (market_leg_id);


--
-- Name: index_bets_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bets_on_user_id ON public.bets USING btree (user_id);


--
-- Name: index_betslip_executions_on_betslip_quote_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_betslip_executions_on_betslip_quote_id ON public.betslip_executions USING btree (betslip_quote_id);


--
-- Name: index_betslip_executions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_betslip_executions_on_user_id ON public.betslip_executions USING btree (user_id);


--
-- Name: index_betslip_quotes_on_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_betslip_quotes_on_idempotency_key ON public.betslip_quotes USING btree (idempotency_key);


--
-- Name: index_betslip_quotes_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_betslip_quotes_on_status ON public.betslip_quotes USING btree (status);


--
-- Name: index_betslip_quotes_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_betslip_quotes_on_user_id ON public.betslip_quotes USING btree (user_id);


--
-- Name: index_faucet_requests_on_reviewed_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_faucet_requests_on_reviewed_by_id ON public.faucet_requests USING btree (reviewed_by_id);


--
-- Name: index_faucet_requests_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_faucet_requests_on_status ON public.faucet_requests USING btree (status);


--
-- Name: index_faucet_requests_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_faucet_requests_on_user_id ON public.faucet_requests USING btree (user_id);


--
-- Name: index_ledger_entries_on_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ledger_entries_on_actor_id ON public.ledger_entries USING btree (actor_id);


--
-- Name: index_ledger_entries_on_entry_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ledger_entries_on_entry_type ON public.ledger_entries USING btree (entry_type);


--
-- Name: index_ledger_entries_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ledger_entries_on_user_id ON public.ledger_entries USING btree (user_id);


--
-- Name: index_market_legs_on_market_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_market_legs_on_market_id ON public.market_legs USING btree (market_id);


--
-- Name: index_market_legs_on_market_id_and_label; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_market_legs_on_market_id_and_label ON public.market_legs USING btree (market_id, label);


--
-- Name: index_market_templates_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_market_templates_on_key ON public.market_templates USING btree (key);


--
-- Name: index_markets_on_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_markets_on_category ON public.markets USING btree (category);


--
-- Name: index_markets_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_markets_on_created_by_id ON public.markets USING btree (created_by_id);


--
-- Name: index_markets_on_settled_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_markets_on_settled_by_id ON public.markets USING btree (settled_by_id);


--
-- Name: index_markets_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_markets_on_status ON public.markets USING btree (status);


--
-- Name: index_orders_book; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_book ON public.orders USING btree (market_id, side, price_cents, status);


--
-- Name: index_orders_on_market_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_market_id ON public.orders USING btree (market_id);


--
-- Name: index_orders_on_market_leg_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_market_leg_id ON public.orders USING btree (market_leg_id);


--
-- Name: index_orders_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_user_id ON public.orders USING btree (user_id);


--
-- Name: index_permissions_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_permissions_on_key ON public.permissions USING btree (key);


--
-- Name: index_price_snapshots_on_market_id_and_recorded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_price_snapshots_on_market_id_and_recorded_at ON public.price_snapshots USING btree (market_id, recorded_at);


--
-- Name: index_role_permissions_on_permission_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_role_permissions_on_permission_id ON public.role_permissions USING btree (permission_id);


--
-- Name: index_role_permissions_on_role_name_and_permission_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_role_permissions_on_role_name_and_permission_id ON public.role_permissions USING btree (role_name, permission_id);


--
-- Name: index_user_grants_on_granted_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_grants_on_granted_by_id ON public.user_grants USING btree (granted_by_id);


--
-- Name: index_user_grants_on_permission_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_grants_on_permission_id ON public.user_grants USING btree (permission_id);


--
-- Name: index_user_grants_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_grants_on_user_id ON public.user_grants USING btree (user_id);


--
-- Name: index_user_grants_on_user_id_and_permission_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_grants_on_user_id_and_permission_id_and_created_at ON public.user_grants USING btree (user_id, permission_id, created_at);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_wallets_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_wallets_on_user_id ON public.wallets USING btree (user_id);


--
-- Name: market_legs enforce_max_two_market_legs; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER enforce_max_two_market_legs BEFORE INSERT ON public.market_legs FOR EACH ROW EXECUTE FUNCTION public.check_market_leg_count();


--
-- Name: market_legs fk_rails_036ca2d27d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_legs
    ADD CONSTRAINT fk_rails_036ca2d27d FOREIGN KEY (market_id) REFERENCES public.markets(id);


--
-- Name: orders fk_rails_134e514517; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT fk_rails_134e514517 FOREIGN KEY (market_leg_id) REFERENCES public.market_legs(id);


--
-- Name: faucet_requests fk_rails_228347e945; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.faucet_requests
    ADD CONSTRAINT fk_rails_228347e945 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: betslip_executions fk_rails_4385a4625e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.betslip_executions
    ADD CONSTRAINT fk_rails_4385a4625e FOREIGN KEY (betslip_quote_id) REFERENCES public.betslip_quotes(id);


--
-- Name: role_permissions fk_rails_439e640a3f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT fk_rails_439e640a3f FOREIGN KEY (permission_id) REFERENCES public.permissions(id);


--
-- Name: user_grants fk_rails_617c37dfa7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_grants
    ADD CONSTRAINT fk_rails_617c37dfa7 FOREIGN KEY (permission_id) REFERENCES public.permissions(id);


--
-- Name: markets fk_rails_6309bf8a67; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.markets
    ADD CONSTRAINT fk_rails_6309bf8a67 FOREIGN KEY (settled_by_id) REFERENCES public.users(id);


--
-- Name: wallets fk_rails_732f6628c4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallets
    ADD CONSTRAINT fk_rails_732f6628c4 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: bets fk_rails_738f400330; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bets
    ADD CONSTRAINT fk_rails_738f400330 FOREIGN KEY (market_id) REFERENCES public.markets(id);


--
-- Name: orders fk_rails_7d6db210d2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT fk_rails_7d6db210d2 FOREIGN KEY (market_id) REFERENCES public.markets(id);


--
-- Name: betslip_quotes fk_rails_8333caff74; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.betslip_quotes
    ADD CONSTRAINT fk_rails_8333caff74 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: bets fk_rails_87dbfdd206; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bets
    ADD CONSTRAINT fk_rails_87dbfdd206 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: faucet_requests fk_rails_905ceb77c8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.faucet_requests
    ADD CONSTRAINT fk_rails_905ceb77c8 FOREIGN KEY (reviewed_by_id) REFERENCES public.users(id);


--
-- Name: ledger_entries fk_rails_ae86e9b3ff; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger_entries
    ADD CONSTRAINT fk_rails_ae86e9b3ff FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: bets fk_rails_b056dfefdf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bets
    ADD CONSTRAINT fk_rails_b056dfefdf FOREIGN KEY (market_leg_id) REFERENCES public.market_legs(id);


--
-- Name: audit_events fk_rails_dd1f3a471a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT fk_rails_dd1f3a471a FOREIGN KEY (actor_id) REFERENCES public.users(id);


--
-- Name: user_grants fk_rails_e16387ee2e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_grants
    ADD CONSTRAINT fk_rails_e16387ee2e FOREIGN KEY (granted_by_id) REFERENCES public.users(id);


--
-- Name: ledger_entries fk_rails_e6ab26e796; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger_entries
    ADD CONSTRAINT fk_rails_e6ab26e796 FOREIGN KEY (actor_id) REFERENCES public.users(id);


--
-- Name: markets fk_rails_e8e0f9129e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.markets
    ADD CONSTRAINT fk_rails_e8e0f9129e FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: betslip_executions fk_rails_f099221393; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.betslip_executions
    ADD CONSTRAINT fk_rails_f099221393 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: price_snapshots fk_rails_f402cbaf76; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_snapshots
    ADD CONSTRAINT fk_rails_f402cbaf76 FOREIGN KEY (market_id) REFERENCES public.markets(id);


--
-- Name: orders fk_rails_f868b47f6a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT fk_rails_f868b47f6a FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: user_grants fk_rails_fd7ee7f838; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_grants
    ADD CONSTRAINT fk_rails_fd7ee7f838 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260528170128'),
('20260528154331'),
('20260527221019'),
('20260527200001'),
('20260527100006'),
('20260527100005'),
('20260527100003'),
('20260527100002'),
('20260527100001'),
('20260526200210'),
('20260526195936'),
('20260526194007'),
('20260525122614'),
('20260525122613'),
('20260525112650'),
('20260525112649'),
('20260525112648'),
('20260525112647'),
('20260525093260'),
('20260525093259'),
('20260525093258'),
('20260525093257'),
('20260525093256'),
('20260525093255'),
('20260525093254');

