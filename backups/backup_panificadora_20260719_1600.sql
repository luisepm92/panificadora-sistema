--
-- PostgreSQL database dump
--

\restrict kwep6xZgKsTmfORnBj2zdp2I1U2gQbSMXCYfG27xM5UNGvw8uC5U6ldcttIA6bb

-- Dumped from database version 15.17
-- Dumped by pg_dump version 15.17

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
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: categoria_cliente; Type: TYPE; Schema: public; Owner: panif_user
--

CREATE TYPE public.categoria_cliente AS ENUM (
    'restaurante',
    'cafeteria',
    'market',
    'otro'
);


ALTER TYPE public.categoria_cliente OWNER TO panif_user;

--
-- Name: estado_cliente; Type: TYPE; Schema: public; Owner: panif_user
--

CREATE TYPE public.estado_cliente AS ENUM (
    'activo',
    'inactivo',
    'bloqueado'
);


ALTER TYPE public.estado_cliente OWNER TO panif_user;

--
-- Name: estado_deuda; Type: TYPE; Schema: public; Owner: panif_user
--

CREATE TYPE public.estado_deuda AS ENUM (
    'pendiente',
    'pagado',
    'parcial',
    'anulado'
);


ALTER TYPE public.estado_deuda OWNER TO panif_user;

--
-- Name: estado_pedido; Type: TYPE; Schema: public; Owner: panif_user
--

CREATE TYPE public.estado_pedido AS ENUM (
    'pendiente',
    'confirmado',
    'entregado',
    'cancelado'
);


ALTER TYPE public.estado_pedido OWNER TO panif_user;

--
-- Name: estado_produccion; Type: TYPE; Schema: public; Owner: panif_user
--

CREATE TYPE public.estado_produccion AS ENUM (
    'pendiente',
    'en_proceso',
    'completado'
);


ALTER TYPE public.estado_produccion OWNER TO panif_user;

--
-- Name: estado_usuario; Type: TYPE; Schema: public; Owner: panif_user
--

CREATE TYPE public.estado_usuario AS ENUM (
    'activo',
    'inactivo'
);


ALTER TYPE public.estado_usuario OWNER TO panif_user;

--
-- Name: metodo_pago; Type: TYPE; Schema: public; Owner: panif_user
--

CREATE TYPE public.metodo_pago AS ENUM (
    'efectivo',
    'transferencia',
    'otro'
);


ALTER TYPE public.metodo_pago OWNER TO panif_user;

--
-- Name: rol_usuario; Type: TYPE; Schema: public; Owner: panif_user
--

CREATE TYPE public.rol_usuario AS ENUM (
    'DUENO',
    'EMPLEADO'
);


ALTER TYPE public.rol_usuario OWNER TO panif_user;

--
-- Name: tipo_unidad; Type: TYPE; Schema: public; Owner: panif_user
--

CREATE TYPE public.tipo_unidad AS ENUM (
    'unidad',
    'paquete'
);


ALTER TYPE public.tipo_unidad OWNER TO panif_user;

--
-- Name: actualizar_estado_deuda(); Type: FUNCTION; Schema: public; Owner: panif_user
--

CREATE FUNCTION public.actualizar_estado_deuda() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE deudas
    SET
        monto_pagado = monto_pagado + NEW.monto_pagado,
        estado = CASE
            WHEN (monto_pagado + NEW.monto_pagado) >= monto_original THEN 'pagado'
            WHEN (monto_pagado + NEW.monto_pagado) > 0               THEN 'parcial'
            ELSE 'pendiente'
        END
    WHERE id_deuda = NEW.id_deuda;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.actualizar_estado_deuda() OWNER TO panif_user;

--
-- Name: consolidar_produccion(date); Type: FUNCTION; Schema: public; Owner: panif_user
--

CREATE FUNCTION public.consolidar_produccion(fecha_prod date) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM produccion_diaria WHERE fecha_produccion = fecha_prod;

    INSERT INTO produccion_diaria (fecha_produccion, tipo_pan, producto, peso_g, total_unidades, peso_total_g)
    SELECT
        fecha_prod,
        dp.tipo_pan,
        dp.producto,
        dp.peso_g,
        SUM(dp.cantidad * COALESCE(pr.paquete_cantidad, 1)),
        SUM(dp.cantidad * COALESCE(pr.paquete_cantidad, 1) * COALESCE(dp.peso_g, 0))
    FROM pedidos p
    JOIN detalle_pedidos dp ON dp.id_pedido = p.id_pedido
    LEFT JOIN productos pr ON pr.nombre = dp.producto
    WHERE p.fecha_produccion_requerida = fecha_prod
      AND p.estado = 'confirmado'
    GROUP BY dp.tipo_pan, dp.producto, dp.peso_g;
END;
$$;


ALTER FUNCTION public.consolidar_produccion(fecha_prod date) OWNER TO panif_user;

--
-- Name: generar_numero_recibo(); Type: FUNCTION; Schema: public; Owner: panif_user
--

CREATE FUNCTION public.generar_numero_recibo() RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    ultimo_num INTEGER;
BEGIN
    SELECT COALESCE(MAX(CAST(numero_recibo AS INTEGER)), 2638)
    INTO ultimo_num FROM pedidos;
    RETURN CAST(ultimo_num + 1 AS VARCHAR);
END;
$$;


ALTER FUNCTION public.generar_numero_recibo() OWNER TO panif_user;

--
-- Name: increment_workflow_version(); Type: FUNCTION; Schema: public; Owner: panif_user
--

CREATE FUNCTION public.increment_workflow_version() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
			BEGIN
				IF NEW."versionCounter" IS NOT DISTINCT FROM OLD."versionCounter" THEN
					NEW."versionCounter" = OLD."versionCounter" + 1;
				END IF;
				RETURN NEW;
			END;
			$$;


ALTER FUNCTION public.increment_workflow_version() OWNER TO panif_user;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: annotation_tag_entity; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.annotation_tag_entity (
    id character varying(16) NOT NULL,
    name character varying(24) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.annotation_tag_entity OWNER TO panif_user;

--
-- Name: auth_identity; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.auth_identity (
    "userId" uuid,
    "providerId" character varying(255) NOT NULL,
    "providerType" character varying(32) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.auth_identity OWNER TO panif_user;

--
-- Name: auth_provider_sync_history; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.auth_provider_sync_history (
    id integer NOT NULL,
    "providerType" character varying(32) NOT NULL,
    "runMode" text NOT NULL,
    status text NOT NULL,
    "startedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "endedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    scanned integer NOT NULL,
    created integer NOT NULL,
    updated integer NOT NULL,
    disabled integer NOT NULL,
    error text
);


ALTER TABLE public.auth_provider_sync_history OWNER TO panif_user;

--
-- Name: auth_provider_sync_history_id_seq; Type: SEQUENCE; Schema: public; Owner: panif_user
--

CREATE SEQUENCE public.auth_provider_sync_history_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.auth_provider_sync_history_id_seq OWNER TO panif_user;

--
-- Name: auth_provider_sync_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: panif_user
--

ALTER SEQUENCE public.auth_provider_sync_history_id_seq OWNED BY public.auth_provider_sync_history.id;


--
-- Name: binary_data; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.binary_data (
    "fileId" uuid NOT NULL,
    "sourceType" character varying(50) NOT NULL,
    "sourceId" character varying(255) NOT NULL,
    data bytea NOT NULL,
    "mimeType" character varying(255),
    "fileName" character varying(255),
    "fileSize" integer NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    CONSTRAINT "CHK_binary_data_sourceType" CHECK ((("sourceType")::text = ANY ((ARRAY['execution'::character varying, 'chat_message_attachment'::character varying])::text[])))
);


ALTER TABLE public.binary_data OWNER TO panif_user;

--
-- Name: COLUMN binary_data."sourceType"; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.binary_data."sourceType" IS 'Source the file belongs to, e.g. ''execution''';


--
-- Name: COLUMN binary_data."sourceId"; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.binary_data."sourceId" IS 'ID of the source, e.g. execution ID';


--
-- Name: COLUMN binary_data.data; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.binary_data.data IS 'Raw, not base64 encoded';


--
-- Name: COLUMN binary_data."fileSize"; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.binary_data."fileSize" IS 'In bytes';


--
-- Name: chat_hub_agent_tools; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.chat_hub_agent_tools (
    "agentId" uuid NOT NULL,
    "toolId" uuid NOT NULL
);


ALTER TABLE public.chat_hub_agent_tools OWNER TO panif_user;

--
-- Name: chat_hub_agents; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.chat_hub_agents (
    id uuid NOT NULL,
    name character varying(256) NOT NULL,
    description character varying(512),
    "systemPrompt" text NOT NULL,
    "ownerId" uuid NOT NULL,
    "credentialId" character varying(36),
    provider character varying(16) NOT NULL,
    model character varying(64) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    icon json,
    files json DEFAULT '[]'::json NOT NULL,
    "suggestedPrompts" json DEFAULT '[]'::json NOT NULL
);


ALTER TABLE public.chat_hub_agents OWNER TO panif_user;

--
-- Name: COLUMN chat_hub_agents.provider; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.chat_hub_agents.provider IS 'ChatHubProvider enum: "openai", "anthropic", "google", "n8n"';


--
-- Name: COLUMN chat_hub_agents.model; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.chat_hub_agents.model IS 'Model name used at the respective Model node, ie. "gpt-4"';


--
-- Name: chat_hub_messages; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.chat_hub_messages (
    id uuid NOT NULL,
    "sessionId" uuid NOT NULL,
    "previousMessageId" uuid,
    "revisionOfMessageId" uuid,
    "retryOfMessageId" uuid,
    type character varying(16) NOT NULL,
    name character varying(128) NOT NULL,
    content text NOT NULL,
    provider character varying(16),
    model character varying(256),
    "workflowId" character varying(36),
    "executionId" integer,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "agentId" uuid,
    status character varying(16) DEFAULT 'success'::character varying NOT NULL,
    attachments json
);


ALTER TABLE public.chat_hub_messages OWNER TO panif_user;

--
-- Name: COLUMN chat_hub_messages.type; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.chat_hub_messages.type IS 'ChatHubMessageType enum: "human", "ai", "system", "tool", "generic"';


--
-- Name: COLUMN chat_hub_messages.provider; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.chat_hub_messages.provider IS 'ChatHubProvider enum: "openai", "anthropic", "google", "n8n"';


--
-- Name: COLUMN chat_hub_messages.model; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.chat_hub_messages.model IS 'Model name used at the respective Model node, ie. "gpt-4"';


--
-- Name: COLUMN chat_hub_messages."agentId"; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.chat_hub_messages."agentId" IS 'ID of the custom agent (if provider is "custom-agent")';


--
-- Name: COLUMN chat_hub_messages.status; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.chat_hub_messages.status IS 'ChatHubMessageStatus enum, eg. "success", "error", "running", "cancelled"';


--
-- Name: COLUMN chat_hub_messages.attachments; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.chat_hub_messages.attachments IS 'File attachments for the message (if any), stored as JSON. Files are stored as base64-encoded data URLs.';


--
-- Name: chat_hub_session_tools; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.chat_hub_session_tools (
    "sessionId" uuid NOT NULL,
    "toolId" uuid NOT NULL
);


ALTER TABLE public.chat_hub_session_tools OWNER TO panif_user;

--
-- Name: chat_hub_sessions; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.chat_hub_sessions (
    id uuid NOT NULL,
    title character varying(256) NOT NULL,
    "ownerId" uuid NOT NULL,
    "lastMessageAt" timestamp(3) with time zone NOT NULL,
    "credentialId" character varying(36),
    provider character varying(16),
    model character varying(256),
    "workflowId" character varying(36),
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "agentId" uuid,
    "agentName" character varying(128)
);


ALTER TABLE public.chat_hub_sessions OWNER TO panif_user;

--
-- Name: COLUMN chat_hub_sessions.provider; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.chat_hub_sessions.provider IS 'ChatHubProvider enum: "openai", "anthropic", "google", "n8n"';


--
-- Name: COLUMN chat_hub_sessions.model; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.chat_hub_sessions.model IS 'Model name used at the respective Model node, ie. "gpt-4"';


--
-- Name: COLUMN chat_hub_sessions."agentId"; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.chat_hub_sessions."agentId" IS 'ID of the custom agent (if provider is "custom-agent")';


--
-- Name: COLUMN chat_hub_sessions."agentName"; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.chat_hub_sessions."agentName" IS 'Cached name of the custom agent (if provider is "custom-agent")';


--
-- Name: chat_hub_tools; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.chat_hub_tools (
    id uuid NOT NULL,
    name character varying(255) NOT NULL,
    type character varying(255) NOT NULL,
    "typeVersion" double precision NOT NULL,
    "ownerId" uuid NOT NULL,
    definition json NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.chat_hub_tools OWNER TO panif_user;

--
-- Name: clientes; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.clientes (
    id_cliente integer NOT NULL,
    telegram_id character varying(100),
    nombre_negocio character varying(200) NOT NULL,
    telefono character varying(50),
    direccion text,
    contacto_principal character varying(200),
    categoria public.categoria_cliente DEFAULT 'otro'::public.categoria_cliente,
    estado public.estado_cliente DEFAULT 'activo'::public.estado_cliente,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.clientes OWNER TO panif_user;

--
-- Name: clientes_id_cliente_seq; Type: SEQUENCE; Schema: public; Owner: panif_user
--

CREATE SEQUENCE public.clientes_id_cliente_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.clientes_id_cliente_seq OWNER TO panif_user;

--
-- Name: clientes_id_cliente_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: panif_user
--

ALTER SEQUENCE public.clientes_id_cliente_seq OWNED BY public.clientes.id_cliente;


--
-- Name: credentials_entity; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.credentials_entity (
    name character varying(128) NOT NULL,
    data text NOT NULL,
    type character varying(128) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    id character varying(36) NOT NULL,
    "isManaged" boolean DEFAULT false NOT NULL,
    "isGlobal" boolean DEFAULT false NOT NULL,
    "isResolvable" boolean DEFAULT false NOT NULL,
    "resolvableAllowFallback" boolean DEFAULT false NOT NULL,
    "resolverId" character varying(16)
);


ALTER TABLE public.credentials_entity OWNER TO panif_user;

--
-- Name: data_table; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.data_table (
    id character varying(36) NOT NULL,
    name character varying(128) NOT NULL,
    "projectId" character varying(36) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.data_table OWNER TO panif_user;

--
-- Name: data_table_column; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.data_table_column (
    id character varying(36) NOT NULL,
    name character varying(128) NOT NULL,
    type character varying(32) NOT NULL,
    index integer NOT NULL,
    "dataTableId" character varying(36) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.data_table_column OWNER TO panif_user;

--
-- Name: COLUMN data_table_column.type; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.data_table_column.type IS 'Expected: string, number, boolean, or date (not enforced as a constraint)';


--
-- Name: COLUMN data_table_column.index; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.data_table_column.index IS 'Column order, starting from 0 (0 = first column)';


--
-- Name: detalle_pedidos; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.detalle_pedidos (
    id_detalle integer NOT NULL,
    id_pedido integer NOT NULL,
    tipo_pan character varying(100) NOT NULL,
    producto character varying(100) NOT NULL,
    peso_g integer,
    cantidad integer NOT NULL,
    tipo_unidad public.tipo_unidad DEFAULT 'unidad'::public.tipo_unidad,
    precio_unitario numeric(10,2) NOT NULL,
    subtotal numeric(10,2) NOT NULL,
    toping character varying(100)
);


ALTER TABLE public.detalle_pedidos OWNER TO panif_user;

--
-- Name: detalle_pedidos_id_detalle_seq; Type: SEQUENCE; Schema: public; Owner: panif_user
--

CREATE SEQUENCE public.detalle_pedidos_id_detalle_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.detalle_pedidos_id_detalle_seq OWNER TO panif_user;

--
-- Name: detalle_pedidos_id_detalle_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: panif_user
--

ALTER SEQUENCE public.detalle_pedidos_id_detalle_seq OWNED BY public.detalle_pedidos.id_detalle;


--
-- Name: deudas; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.deudas (
    id_deuda integer NOT NULL,
    id_cliente integer NOT NULL,
    id_pedido integer,
    monto_original numeric(10,2) NOT NULL,
    monto_pagado numeric(10,2) DEFAULT 0,
    saldo_pendiente numeric(10,2) GENERATED ALWAYS AS ((monto_original - monto_pagado)) STORED,
    estado public.estado_deuda DEFAULT 'pendiente'::public.estado_deuda,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_vencimiento date,
    descripcion text
);


ALTER TABLE public.deudas OWNER TO panif_user;

--
-- Name: deudas_id_deuda_seq; Type: SEQUENCE; Schema: public; Owner: panif_user
--

CREATE SEQUENCE public.deudas_id_deuda_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.deudas_id_deuda_seq OWNER TO panif_user;

--
-- Name: deudas_id_deuda_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: panif_user
--

ALTER SEQUENCE public.deudas_id_deuda_seq OWNED BY public.deudas.id_deuda;


--
-- Name: dynamic_credential_entry; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.dynamic_credential_entry (
    credential_id character varying(16) NOT NULL,
    subject_id character varying(2048) NOT NULL,
    resolver_id character varying(16) NOT NULL,
    data text NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.dynamic_credential_entry OWNER TO panif_user;

--
-- Name: dynamic_credential_resolver; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.dynamic_credential_resolver (
    id character varying(16) NOT NULL,
    name character varying(128) NOT NULL,
    type character varying(128) NOT NULL,
    config text NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.dynamic_credential_resolver OWNER TO panif_user;

--
-- Name: COLUMN dynamic_credential_resolver.config; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.dynamic_credential_resolver.config IS 'Encrypted resolver configuration (JSON encrypted as string)';


--
-- Name: dynamic_credential_user_entry; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.dynamic_credential_user_entry (
    "credentialId" character varying(16) NOT NULL,
    "userId" uuid NOT NULL,
    "resolverId" character varying(16) NOT NULL,
    data text NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.dynamic_credential_user_entry OWNER TO panif_user;

--
-- Name: event_destinations; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.event_destinations (
    id uuid NOT NULL,
    destination jsonb NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.event_destinations OWNER TO panif_user;

--
-- Name: execution_annotation_tags; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.execution_annotation_tags (
    "annotationId" integer NOT NULL,
    "tagId" character varying(24) NOT NULL
);


ALTER TABLE public.execution_annotation_tags OWNER TO panif_user;

--
-- Name: execution_annotations; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.execution_annotations (
    id integer NOT NULL,
    "executionId" integer NOT NULL,
    vote character varying(6),
    note text,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.execution_annotations OWNER TO panif_user;

--
-- Name: execution_annotations_id_seq; Type: SEQUENCE; Schema: public; Owner: panif_user
--

CREATE SEQUENCE public.execution_annotations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.execution_annotations_id_seq OWNER TO panif_user;

--
-- Name: execution_annotations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: panif_user
--

ALTER SEQUENCE public.execution_annotations_id_seq OWNED BY public.execution_annotations.id;


--
-- Name: execution_data; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.execution_data (
    "executionId" integer NOT NULL,
    "workflowData" json NOT NULL,
    data text NOT NULL,
    "workflowVersionId" character varying(36)
);


ALTER TABLE public.execution_data OWNER TO panif_user;

--
-- Name: execution_entity; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.execution_entity (
    id integer NOT NULL,
    finished boolean NOT NULL,
    mode character varying NOT NULL,
    "retryOf" character varying,
    "retrySuccessId" character varying,
    "startedAt" timestamp(3) with time zone,
    "stoppedAt" timestamp(3) with time zone,
    "waitTill" timestamp(3) with time zone,
    status character varying NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    "deletedAt" timestamp(3) with time zone,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "storedAt" character varying(2) DEFAULT 'db'::character varying NOT NULL,
    CONSTRAINT "execution_entity_storedAt_check" CHECK ((("storedAt")::text = ANY ((ARRAY['db'::character varying, 'fs'::character varying, 's3'::character varying])::text[])))
);


ALTER TABLE public.execution_entity OWNER TO panif_user;

--
-- Name: execution_entity_id_seq; Type: SEQUENCE; Schema: public; Owner: panif_user
--

CREATE SEQUENCE public.execution_entity_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.execution_entity_id_seq OWNER TO panif_user;

--
-- Name: execution_entity_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: panif_user
--

ALTER SEQUENCE public.execution_entity_id_seq OWNED BY public.execution_entity.id;


--
-- Name: execution_metadata; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.execution_metadata (
    id integer NOT NULL,
    "executionId" integer NOT NULL,
    key character varying(255) NOT NULL,
    value text NOT NULL
);


ALTER TABLE public.execution_metadata OWNER TO panif_user;

--
-- Name: execution_metadata_temp_id_seq; Type: SEQUENCE; Schema: public; Owner: panif_user
--

CREATE SEQUENCE public.execution_metadata_temp_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.execution_metadata_temp_id_seq OWNER TO panif_user;

--
-- Name: execution_metadata_temp_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: panif_user
--

ALTER SEQUENCE public.execution_metadata_temp_id_seq OWNED BY public.execution_metadata.id;


--
-- Name: folder; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.folder (
    id character varying(36) NOT NULL,
    name character varying(128) NOT NULL,
    "parentFolderId" character varying(36),
    "projectId" character varying(36) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.folder OWNER TO panif_user;

--
-- Name: folder_tag; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.folder_tag (
    "folderId" character varying(36) NOT NULL,
    "tagId" character varying(36) NOT NULL
);


ALTER TABLE public.folder_tag OWNER TO panif_user;

--
-- Name: insights_by_period; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.insights_by_period (
    id integer NOT NULL,
    "metaId" integer NOT NULL,
    type integer NOT NULL,
    value bigint NOT NULL,
    "periodUnit" integer NOT NULL,
    "periodStart" timestamp(0) with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.insights_by_period OWNER TO panif_user;

--
-- Name: COLUMN insights_by_period.type; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.insights_by_period.type IS '0: time_saved_minutes, 1: runtime_milliseconds, 2: success, 3: failure';


--
-- Name: COLUMN insights_by_period."periodUnit"; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.insights_by_period."periodUnit" IS '0: hour, 1: day, 2: week';


--
-- Name: insights_by_period_id_seq; Type: SEQUENCE; Schema: public; Owner: panif_user
--

ALTER TABLE public.insights_by_period ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.insights_by_period_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: insights_metadata; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.insights_metadata (
    "metaId" integer NOT NULL,
    "workflowId" character varying(36),
    "projectId" character varying(36),
    "workflowName" character varying(128) NOT NULL,
    "projectName" character varying(255) NOT NULL
);


ALTER TABLE public.insights_metadata OWNER TO panif_user;

--
-- Name: insights_metadata_metaId_seq; Type: SEQUENCE; Schema: public; Owner: panif_user
--

ALTER TABLE public.insights_metadata ALTER COLUMN "metaId" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public."insights_metadata_metaId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: insights_raw; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.insights_raw (
    id integer NOT NULL,
    "metaId" integer NOT NULL,
    type integer NOT NULL,
    value bigint NOT NULL,
    "timestamp" timestamp(0) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.insights_raw OWNER TO panif_user;

--
-- Name: COLUMN insights_raw.type; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.insights_raw.type IS '0: time_saved_minutes, 1: runtime_milliseconds, 2: success, 3: failure';


--
-- Name: insights_raw_id_seq; Type: SEQUENCE; Schema: public; Owner: panif_user
--

ALTER TABLE public.insights_raw ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.insights_raw_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: installed_nodes; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.installed_nodes (
    name character varying(200) NOT NULL,
    type character varying(200) NOT NULL,
    "latestVersion" integer DEFAULT 1 NOT NULL,
    package character varying(241) NOT NULL
);


ALTER TABLE public.installed_nodes OWNER TO panif_user;

--
-- Name: installed_packages; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.installed_packages (
    "packageName" character varying(214) NOT NULL,
    "installedVersion" character varying(50) NOT NULL,
    "authorName" character varying(70),
    "authorEmail" character varying(70),
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.installed_packages OWNER TO panif_user;

--
-- Name: invalid_auth_token; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.invalid_auth_token (
    token character varying(512) NOT NULL,
    "expiresAt" timestamp(3) with time zone NOT NULL
);


ALTER TABLE public.invalid_auth_token OWNER TO panif_user;

--
-- Name: migrations; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.migrations (
    id integer NOT NULL,
    "timestamp" bigint NOT NULL,
    name character varying NOT NULL
);


ALTER TABLE public.migrations OWNER TO panif_user;

--
-- Name: migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: panif_user
--

CREATE SEQUENCE public.migrations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.migrations_id_seq OWNER TO panif_user;

--
-- Name: migrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: panif_user
--

ALTER SEQUENCE public.migrations_id_seq OWNED BY public.migrations.id;


--
-- Name: oauth_access_tokens; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.oauth_access_tokens (
    token character varying NOT NULL,
    "clientId" character varying NOT NULL,
    "userId" uuid NOT NULL
);


ALTER TABLE public.oauth_access_tokens OWNER TO panif_user;

--
-- Name: oauth_authorization_codes; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.oauth_authorization_codes (
    code character varying(255) NOT NULL,
    "clientId" character varying NOT NULL,
    "userId" uuid NOT NULL,
    "redirectUri" character varying NOT NULL,
    "codeChallenge" character varying NOT NULL,
    "codeChallengeMethod" character varying(255) NOT NULL,
    "expiresAt" bigint NOT NULL,
    state character varying,
    used boolean DEFAULT false NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.oauth_authorization_codes OWNER TO panif_user;

--
-- Name: COLUMN oauth_authorization_codes."expiresAt"; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.oauth_authorization_codes."expiresAt" IS 'Unix timestamp in milliseconds';


--
-- Name: oauth_clients; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.oauth_clients (
    id character varying NOT NULL,
    name character varying(255) NOT NULL,
    "redirectUris" json NOT NULL,
    "grantTypes" json NOT NULL,
    "clientSecret" character varying(255),
    "clientSecretExpiresAt" bigint,
    "tokenEndpointAuthMethod" character varying(255) DEFAULT 'none'::character varying NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.oauth_clients OWNER TO panif_user;

--
-- Name: COLUMN oauth_clients."tokenEndpointAuthMethod"; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.oauth_clients."tokenEndpointAuthMethod" IS 'Possible values: none, client_secret_basic or client_secret_post';


--
-- Name: oauth_refresh_tokens; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.oauth_refresh_tokens (
    token character varying(255) NOT NULL,
    "clientId" character varying NOT NULL,
    "userId" uuid NOT NULL,
    "expiresAt" bigint NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.oauth_refresh_tokens OWNER TO panif_user;

--
-- Name: COLUMN oauth_refresh_tokens."expiresAt"; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.oauth_refresh_tokens."expiresAt" IS 'Unix timestamp in milliseconds';


--
-- Name: oauth_user_consents; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.oauth_user_consents (
    id integer NOT NULL,
    "userId" uuid NOT NULL,
    "clientId" character varying NOT NULL,
    "grantedAt" bigint NOT NULL
);


ALTER TABLE public.oauth_user_consents OWNER TO panif_user;

--
-- Name: COLUMN oauth_user_consents."grantedAt"; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.oauth_user_consents."grantedAt" IS 'Unix timestamp in milliseconds';


--
-- Name: oauth_user_consents_id_seq; Type: SEQUENCE; Schema: public; Owner: panif_user
--

ALTER TABLE public.oauth_user_consents ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.oauth_user_consents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: pagos; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.pagos (
    id_pago integer NOT NULL,
    id_deuda integer NOT NULL,
    id_cliente integer NOT NULL,
    monto_pagado numeric(10,2) NOT NULL,
    fecha_pago timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    metodo public.metodo_pago DEFAULT 'efectivo'::public.metodo_pago,
    registrado_por character varying(200) NOT NULL,
    notas text
);


ALTER TABLE public.pagos OWNER TO panif_user;

--
-- Name: pagos_id_pago_seq; Type: SEQUENCE; Schema: public; Owner: panif_user
--

CREATE SEQUENCE public.pagos_id_pago_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pagos_id_pago_seq OWNER TO panif_user;

--
-- Name: pagos_id_pago_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: panif_user
--

ALTER SEQUENCE public.pagos_id_pago_seq OWNED BY public.pagos.id_pago;


--
-- Name: pedidos; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.pedidos (
    id_pedido integer NOT NULL,
    id_cliente integer NOT NULL,
    numero_recibo character varying(20) NOT NULL,
    fecha_pedido timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_entrega date NOT NULL,
    estado public.estado_pedido DEFAULT 'pendiente'::public.estado_pedido,
    monto_total numeric(10,2) DEFAULT 0,
    archivo_pdf_url text,
    observaciones text,
    registrado_por character varying(200),
    fecha_produccion_requerida date,
    fecha_despacho_real date,
    confirmado_por_admin boolean DEFAULT false,
    fecha_confirmacion_admin timestamp without time zone,
    despacho_confirmado boolean DEFAULT false,
    fecha_confirmacion_despacho timestamp without time zone,
    monto_delivery numeric(10,2) DEFAULT 0,
    aplica_iva boolean DEFAULT false
);


ALTER TABLE public.pedidos OWNER TO panif_user;

--
-- Name: pedidos_id_pedido_seq; Type: SEQUENCE; Schema: public; Owner: panif_user
--

CREATE SEQUENCE public.pedidos_id_pedido_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pedidos_id_pedido_seq OWNER TO panif_user;

--
-- Name: pedidos_id_pedido_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: panif_user
--

ALTER SEQUENCE public.pedidos_id_pedido_seq OWNED BY public.pedidos.id_pedido;


--
-- Name: processed_data; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.processed_data (
    "workflowId" character varying(36) NOT NULL,
    context character varying(255) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    value text NOT NULL
);


ALTER TABLE public.processed_data OWNER TO panif_user;

--
-- Name: produccion_diaria; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.produccion_diaria (
    id_produccion integer NOT NULL,
    fecha_produccion date NOT NULL,
    tipo_pan character varying(100) NOT NULL,
    producto character varying(100) NOT NULL,
    peso_g integer,
    total_unidades integer NOT NULL,
    peso_total_g numeric(10,2),
    estado public.estado_produccion DEFAULT 'pendiente'::public.estado_produccion,
    fecha_produccion_requerida date,
    cliente character varying(100),
    id_pedido integer
);


ALTER TABLE public.produccion_diaria OWNER TO panif_user;

--
-- Name: produccion_diaria_id_produccion_seq; Type: SEQUENCE; Schema: public; Owner: panif_user
--

CREATE SEQUENCE public.produccion_diaria_id_produccion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.produccion_diaria_id_produccion_seq OWNER TO panif_user;

--
-- Name: produccion_diaria_id_produccion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: panif_user
--

ALTER SEQUENCE public.produccion_diaria_id_produccion_seq OWNED BY public.produccion_diaria.id_produccion;


--
-- Name: productos; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.productos (
    id_producto integer NOT NULL,
    nombre character varying(200) NOT NULL,
    tipo_masa character varying(50) NOT NULL,
    tipo_pan character varying(100) NOT NULL,
    peso_g integer,
    precio_unitario numeric(10,2) NOT NULL,
    paquete_cantidad integer,
    paquete_tipo character varying(50),
    descripcion text,
    activo boolean DEFAULT true,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_ultima_modificacion timestamp without time zone DEFAULT now()
);


ALTER TABLE public.productos OWNER TO panif_user;

--
-- Name: productos_id_producto_seq; Type: SEQUENCE; Schema: public; Owner: panif_user
--

CREATE SEQUENCE public.productos_id_producto_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.productos_id_producto_seq OWNER TO panif_user;

--
-- Name: productos_id_producto_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: panif_user
--

ALTER SEQUENCE public.productos_id_producto_seq OWNED BY public.productos.id_producto;


--
-- Name: project; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.project (
    id character varying(36) NOT NULL,
    name character varying(255) NOT NULL,
    type character varying(36) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    icon json,
    description character varying(512),
    "creatorId" uuid
);


ALTER TABLE public.project OWNER TO panif_user;

--
-- Name: COLUMN project."creatorId"; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.project."creatorId" IS 'ID of the user who created the project';


--
-- Name: project_relation; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.project_relation (
    "projectId" character varying(36) NOT NULL,
    "userId" uuid NOT NULL,
    role character varying NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.project_relation OWNER TO panif_user;

--
-- Name: project_secrets_provider_access; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.project_secrets_provider_access (
    "secretsProviderConnectionId" integer NOT NULL,
    "projectId" character varying(36) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    role character varying(128) DEFAULT 'secretsProviderConnection:user'::character varying NOT NULL,
    CONSTRAINT "CHK_project_secrets_provider_access_role" CHECK (((role)::text = ANY ((ARRAY['secretsProviderConnection:owner'::character varying, 'secretsProviderConnection:user'::character varying])::text[])))
);


ALTER TABLE public.project_secrets_provider_access OWNER TO panif_user;

--
-- Name: recetas_masa; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.recetas_masa (
    id_receta integer NOT NULL,
    tipo_masa character varying(100) NOT NULL,
    ingrediente character varying(100) NOT NULL,
    cantidad_por_kg_masa numeric(10,4) NOT NULL,
    unidad character varying(20) DEFAULT 'kg'::character varying
);


ALTER TABLE public.recetas_masa OWNER TO panif_user;

--
-- Name: recetas_masa_id_receta_seq; Type: SEQUENCE; Schema: public; Owner: panif_user
--

CREATE SEQUENCE public.recetas_masa_id_receta_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.recetas_masa_id_receta_seq OWNER TO panif_user;

--
-- Name: recetas_masa_id_receta_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: panif_user
--

ALTER SEQUENCE public.recetas_masa_id_receta_seq OWNED BY public.recetas_masa.id_receta;


--
-- Name: role; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.role (
    slug character varying(128) NOT NULL,
    "displayName" text,
    description text,
    "roleType" text,
    "systemRole" boolean DEFAULT false NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.role OWNER TO panif_user;

--
-- Name: COLUMN role.slug; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.role.slug IS 'Unique identifier of the role for example: "global:owner"';


--
-- Name: COLUMN role."displayName"; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.role."displayName" IS 'Name used to display in the UI';


--
-- Name: COLUMN role.description; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.role.description IS 'Text describing the scope in more detail of users';


--
-- Name: COLUMN role."roleType"; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.role."roleType" IS 'Type of the role, e.g., global, project, or workflow';


--
-- Name: COLUMN role."systemRole"; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.role."systemRole" IS 'Indicates if the role is managed by the system and cannot be edited';


--
-- Name: role_scope; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.role_scope (
    "roleSlug" character varying(128) NOT NULL,
    "scopeSlug" character varying(128) NOT NULL
);


ALTER TABLE public.role_scope OWNER TO panif_user;

--
-- Name: scope; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.scope (
    slug character varying(128) NOT NULL,
    "displayName" text,
    description text
);


ALTER TABLE public.scope OWNER TO panif_user;

--
-- Name: COLUMN scope.slug; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.scope.slug IS 'Unique identifier of the scope for example: "project:create"';


--
-- Name: COLUMN scope."displayName"; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.scope."displayName" IS 'Name used to display in the UI';


--
-- Name: COLUMN scope.description; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.scope.description IS 'Text describing the scope in more detail of users';


--
-- Name: secrets_provider_connection; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.secrets_provider_connection (
    id integer NOT NULL,
    "providerKey" character varying(128) NOT NULL,
    type character varying(36) NOT NULL,
    "encryptedSettings" text NOT NULL,
    "isEnabled" boolean DEFAULT false NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.secrets_provider_connection OWNER TO panif_user;

--
-- Name: COLUMN secrets_provider_connection.type; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.secrets_provider_connection.type IS 'Type of secrets provider. Possible values: awsSecretsManager, gcpSecretsManager, vault, azureKeyVault, infisical';


--
-- Name: secrets_provider_connection_id_seq; Type: SEQUENCE; Schema: public; Owner: panif_user
--

ALTER TABLE public.secrets_provider_connection ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.secrets_provider_connection_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: settings; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.settings (
    key character varying(255) NOT NULL,
    value text NOT NULL,
    "loadOnStartup" boolean DEFAULT false NOT NULL
);


ALTER TABLE public.settings OWNER TO panif_user;

--
-- Name: shared_credentials; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.shared_credentials (
    "credentialsId" character varying(36) NOT NULL,
    "projectId" character varying(36) NOT NULL,
    role text NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.shared_credentials OWNER TO panif_user;

--
-- Name: shared_workflow; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.shared_workflow (
    "workflowId" character varying(36) NOT NULL,
    "projectId" character varying(36) NOT NULL,
    role text NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.shared_workflow OWNER TO panif_user;

--
-- Name: tag_entity; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.tag_entity (
    name character varying(24) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    id character varying(36) NOT NULL
);


ALTER TABLE public.tag_entity OWNER TO panif_user;

--
-- Name: test_case_execution; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.test_case_execution (
    id character varying(36) NOT NULL,
    "testRunId" character varying(36) NOT NULL,
    "executionId" integer,
    status character varying NOT NULL,
    "runAt" timestamp(3) with time zone,
    "completedAt" timestamp(3) with time zone,
    "errorCode" character varying,
    "errorDetails" json,
    metrics json,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    inputs json,
    outputs json
);


ALTER TABLE public.test_case_execution OWNER TO panif_user;

--
-- Name: test_run; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.test_run (
    id character varying(36) NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    status character varying NOT NULL,
    "errorCode" character varying,
    "errorDetails" json,
    "runAt" timestamp(3) with time zone,
    "completedAt" timestamp(3) with time zone,
    metrics json,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "runningInstanceId" character varying(255),
    "cancelRequested" boolean DEFAULT false NOT NULL
);


ALTER TABLE public.test_run OWNER TO panif_user;

--
-- Name: tipos_masa; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.tipos_masa (
    tipo_masa character varying(100) NOT NULL,
    peso_masa_g integer NOT NULL,
    descripcion text,
    activo boolean DEFAULT true,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.tipos_masa OWNER TO panif_user;

--
-- Name: topings; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.topings (
    id_toping integer NOT NULL,
    nombre character varying(100) NOT NULL,
    activo boolean DEFAULT true
);


ALTER TABLE public.topings OWNER TO panif_user;

--
-- Name: topings_id_toping_seq; Type: SEQUENCE; Schema: public; Owner: panif_user
--

CREATE SEQUENCE public.topings_id_toping_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.topings_id_toping_seq OWNER TO panif_user;

--
-- Name: topings_id_toping_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: panif_user
--

ALTER SEQUENCE public.topings_id_toping_seq OWNED BY public.topings.id_toping;


--
-- Name: user; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public."user" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email character varying(255),
    "firstName" character varying(32),
    "lastName" character varying(32),
    password character varying(255),
    "personalizationAnswers" json,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    settings json,
    disabled boolean DEFAULT false NOT NULL,
    "mfaEnabled" boolean DEFAULT false NOT NULL,
    "mfaSecret" text,
    "mfaRecoveryCodes" text,
    "lastActiveAt" date,
    "roleSlug" character varying(128) DEFAULT 'global:member'::character varying NOT NULL
);


ALTER TABLE public."user" OWNER TO panif_user;

--
-- Name: user_api_keys; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.user_api_keys (
    id character varying(36) NOT NULL,
    "userId" uuid NOT NULL,
    label character varying(100) NOT NULL,
    "apiKey" character varying NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    scopes json,
    audience character varying DEFAULT 'public-api'::character varying NOT NULL
);


ALTER TABLE public.user_api_keys OWNER TO panif_user;

--
-- Name: usuarios; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.usuarios (
    id_usuario integer NOT NULL,
    telegram_id character varying(100) NOT NULL,
    nombre character varying(200) NOT NULL,
    rol public.rol_usuario DEFAULT 'EMPLEADO'::public.rol_usuario,
    estado public.estado_usuario DEFAULT 'activo'::public.estado_usuario,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    ultimo_acceso timestamp without time zone
);


ALTER TABLE public.usuarios OWNER TO panif_user;

--
-- Name: usuarios_dashboard; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.usuarios_dashboard (
    id integer NOT NULL,
    usuario character varying(50) NOT NULL,
    "contraseña" character varying(255) NOT NULL,
    nombre character varying(100),
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.usuarios_dashboard OWNER TO panif_user;

--
-- Name: usuarios_dashboard_id_seq; Type: SEQUENCE; Schema: public; Owner: panif_user
--

CREATE SEQUENCE public.usuarios_dashboard_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.usuarios_dashboard_id_seq OWNER TO panif_user;

--
-- Name: usuarios_dashboard_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: panif_user
--

ALTER SEQUENCE public.usuarios_dashboard_id_seq OWNED BY public.usuarios_dashboard.id;


--
-- Name: usuarios_id_usuario_seq; Type: SEQUENCE; Schema: public; Owner: panif_user
--

CREATE SEQUENCE public.usuarios_id_usuario_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.usuarios_id_usuario_seq OWNER TO panif_user;

--
-- Name: usuarios_id_usuario_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: panif_user
--

ALTER SEQUENCE public.usuarios_id_usuario_seq OWNED BY public.usuarios.id_usuario;


--
-- Name: variables; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.variables (
    key character varying(50) NOT NULL,
    type character varying(50) DEFAULT 'string'::character varying NOT NULL,
    value character varying(255),
    id character varying(36) NOT NULL,
    "projectId" character varying(36)
);


ALTER TABLE public.variables OWNER TO panif_user;

--
-- Name: vista_deuda_clientes; Type: VIEW; Schema: public; Owner: panif_user
--

CREATE VIEW public.vista_deuda_clientes AS
 SELECT c.id_cliente,
    c.nombre_negocio,
    c.telefono,
    COALESCE(sum(d.monto_original) FILTER (WHERE (d.estado <> 'anulado'::public.estado_deuda)), (0)::numeric) AS total_pedidos,
    COALESCE(sum(d.monto_pagado) FILTER (WHERE (d.estado <> 'anulado'::public.estado_deuda)), (0)::numeric) AS total_pagado,
    COALESCE(sum(d.saldo_pendiente) FILTER (WHERE (d.estado <> ALL (ARRAY['pagado'::public.estado_deuda, 'anulado'::public.estado_deuda]))), (0)::numeric) AS deuda_total,
    count(d.id_deuda) FILTER (WHERE (d.estado <> ALL (ARRAY['pagado'::public.estado_deuda, 'anulado'::public.estado_deuda]))) AS pedidos_pendientes,
    max(p.fecha_pedido) AS ultimo_pedido
   FROM ((public.clientes c
     LEFT JOIN public.deudas d ON ((d.id_cliente = c.id_cliente)))
     LEFT JOIN public.pedidos p ON ((p.id_cliente = c.id_cliente)))
  WHERE (c.estado = 'activo'::public.estado_cliente)
  GROUP BY c.id_cliente, c.nombre_negocio, c.telefono
  ORDER BY COALESCE(sum(d.saldo_pendiente) FILTER (WHERE (d.estado <> ALL (ARRAY['pagado'::public.estado_deuda, 'anulado'::public.estado_deuda]))), (0)::numeric) DESC;


ALTER TABLE public.vista_deuda_clientes OWNER TO panif_user;

--
-- Name: vista_ingredientes_por_fecha; Type: VIEW; Schema: public; Owner: panif_user
--

CREATE VIEW public.vista_ingredientes_por_fecha AS
 SELECT pd.fecha_produccion_requerida,
    rm.ingrediente,
    sum(((((pd.total_unidades)::numeric * (pd.peso_g)::numeric) / 1000.0) * rm.cantidad_por_kg_masa)) AS cantidad_total,
    rm.unidad
   FROM (public.produccion_diaria pd
     JOIN public.recetas_masa rm ON (((rm.tipo_masa)::text = (pd.tipo_pan)::text)))
  WHERE (pd.fecha_produccion_requerida IS NOT NULL)
  GROUP BY pd.fecha_produccion_requerida, rm.ingrediente, rm.unidad
  ORDER BY pd.fecha_produccion_requerida, rm.ingrediente;


ALTER TABLE public.vista_ingredientes_por_fecha OWNER TO panif_user;

--
-- Name: vista_produccion_manana; Type: VIEW; Schema: public; Owner: panif_user
--

CREATE VIEW public.vista_produccion_manana AS
 SELECT ddp.tipo_pan,
    ddp.producto,
    ddp.peso_g,
    sum(ddp.cantidad) AS total_unidades,
    sum((ddp.cantidad * ddp.peso_g)) AS peso_total_g,
    string_agg(DISTINCT (c.nombre_negocio)::text, ', '::text) AS clientes
   FROM ((public.pedidos p
     JOIN public.detalle_pedidos ddp ON ((ddp.id_pedido = p.id_pedido)))
     JOIN public.clientes c ON ((c.id_cliente = p.id_cliente)))
  WHERE ((p.fecha_entrega = (CURRENT_DATE + '1 day'::interval)) AND (p.estado = 'confirmado'::public.estado_pedido))
  GROUP BY ddp.tipo_pan, ddp.producto, ddp.peso_g
  ORDER BY ddp.tipo_pan, ddp.peso_g;


ALTER TABLE public.vista_produccion_manana OWNER TO panif_user;

--
-- Name: vista_produccion_por_fecha; Type: VIEW; Schema: public; Owner: panif_user
--

CREATE VIEW public.vista_produccion_por_fecha AS
 SELECT produccion_diaria.fecha_produccion_requerida,
    produccion_diaria.tipo_pan,
    sum(produccion_diaria.total_unidades) AS total_unidades,
    string_agg(DISTINCT (produccion_diaria.cliente)::text, ', '::text) AS clientes
   FROM public.produccion_diaria
  GROUP BY produccion_diaria.fecha_produccion_requerida, produccion_diaria.tipo_pan
  ORDER BY produccion_diaria.fecha_produccion_requerida, produccion_diaria.tipo_pan;


ALTER TABLE public.vista_produccion_por_fecha OWNER TO panif_user;

--
-- Name: vista_top_deudores; Type: VIEW; Schema: public; Owner: panif_user
--

CREATE VIEW public.vista_top_deudores AS
 SELECT vista_deuda_clientes.nombre_negocio,
    vista_deuda_clientes.deuda_total,
    vista_deuda_clientes.total_pedidos,
    vista_deuda_clientes.total_pagado,
    vista_deuda_clientes.pedidos_pendientes
   FROM public.vista_deuda_clientes
  WHERE (vista_deuda_clientes.deuda_total > (0)::numeric)
  ORDER BY vista_deuda_clientes.deuda_total DESC
 LIMIT 10;


ALTER TABLE public.vista_top_deudores OWNER TO panif_user;

--
-- Name: webhook_entity; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.webhook_entity (
    "webhookPath" character varying NOT NULL,
    method character varying NOT NULL,
    node character varying NOT NULL,
    "webhookId" character varying,
    "pathLength" integer,
    "workflowId" character varying(36) NOT NULL
);


ALTER TABLE public.webhook_entity OWNER TO panif_user;

--
-- Name: workflow_builder_session; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.workflow_builder_session (
    id uuid NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    "userId" uuid NOT NULL,
    messages json DEFAULT '[]'::json NOT NULL,
    "previousSummary" text,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.workflow_builder_session OWNER TO panif_user;

--
-- Name: COLUMN workflow_builder_session."previousSummary"; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.workflow_builder_session."previousSummary" IS 'Summary of prior conversation from compaction (/compact or auto-compact)';


--
-- Name: workflow_dependency; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.workflow_dependency (
    id integer NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    "workflowVersionId" integer NOT NULL,
    "dependencyType" character varying(32) NOT NULL,
    "dependencyKey" character varying(255) NOT NULL,
    "dependencyInfo" json,
    "indexVersionId" smallint DEFAULT 1 NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "publishedVersionId" character varying(36)
);


ALTER TABLE public.workflow_dependency OWNER TO panif_user;

--
-- Name: COLUMN workflow_dependency."workflowVersionId"; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.workflow_dependency."workflowVersionId" IS 'Version of the workflow';


--
-- Name: COLUMN workflow_dependency."dependencyType"; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.workflow_dependency."dependencyType" IS 'Type of dependency: "credential", "nodeType", "webhookPath", or "workflowCall"';


--
-- Name: COLUMN workflow_dependency."dependencyKey"; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.workflow_dependency."dependencyKey" IS 'ID or name of the dependency';


--
-- Name: COLUMN workflow_dependency."dependencyInfo"; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.workflow_dependency."dependencyInfo" IS 'Additional info about the dependency, interpreted based on type';


--
-- Name: COLUMN workflow_dependency."indexVersionId"; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.workflow_dependency."indexVersionId" IS 'Version of the index structure';


--
-- Name: workflow_dependency_id_seq; Type: SEQUENCE; Schema: public; Owner: panif_user
--

ALTER TABLE public.workflow_dependency ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.workflow_dependency_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: workflow_entity; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.workflow_entity (
    name character varying(128) NOT NULL,
    active boolean NOT NULL,
    nodes json NOT NULL,
    connections json NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    settings json,
    "staticData" json,
    "pinData" json,
    "versionId" character(36) NOT NULL,
    "triggerCount" integer DEFAULT 0 NOT NULL,
    id character varying(36) NOT NULL,
    meta json,
    "parentFolderId" character varying(36) DEFAULT NULL::character varying,
    "isArchived" boolean DEFAULT false NOT NULL,
    "versionCounter" integer DEFAULT 1 NOT NULL,
    description text,
    "activeVersionId" character varying(36)
);


ALTER TABLE public.workflow_entity OWNER TO panif_user;

--
-- Name: workflow_history; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.workflow_history (
    "versionId" character varying(36) NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    authors character varying(255) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    nodes json NOT NULL,
    connections json NOT NULL,
    name character varying(128),
    autosaved boolean DEFAULT false NOT NULL,
    description text
);


ALTER TABLE public.workflow_history OWNER TO panif_user;

--
-- Name: workflow_publish_history; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.workflow_publish_history (
    id integer NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    "versionId" character varying(36) NOT NULL,
    event character varying(36) NOT NULL,
    "userId" uuid,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    CONSTRAINT "CHK_workflow_publish_history_event" CHECK (((event)::text = ANY ((ARRAY['activated'::character varying, 'deactivated'::character varying])::text[])))
);


ALTER TABLE public.workflow_publish_history OWNER TO panif_user;

--
-- Name: COLUMN workflow_publish_history.event; Type: COMMENT; Schema: public; Owner: panif_user
--

COMMENT ON COLUMN public.workflow_publish_history.event IS 'Type of history record: activated (workflow is now active), deactivated (workflow is now inactive)';


--
-- Name: workflow_publish_history_id_seq; Type: SEQUENCE; Schema: public; Owner: panif_user
--

ALTER TABLE public.workflow_publish_history ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.workflow_publish_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: workflow_published_version; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.workflow_published_version (
    "workflowId" character varying(36) NOT NULL,
    "publishedVersionId" character varying(36) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.workflow_published_version OWNER TO panif_user;

--
-- Name: workflow_statistics; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.workflow_statistics (
    count bigint DEFAULT 0,
    "latestEvent" timestamp(3) with time zone,
    name character varying(128) NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    "rootCount" bigint DEFAULT 0,
    id integer NOT NULL,
    "workflowName" character varying(128)
);


ALTER TABLE public.workflow_statistics OWNER TO panif_user;

--
-- Name: workflow_statistics_id_seq; Type: SEQUENCE; Schema: public; Owner: panif_user
--

CREATE SEQUENCE public.workflow_statistics_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.workflow_statistics_id_seq OWNER TO panif_user;

--
-- Name: workflow_statistics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: panif_user
--

ALTER SEQUENCE public.workflow_statistics_id_seq OWNED BY public.workflow_statistics.id;


--
-- Name: workflows_tags; Type: TABLE; Schema: public; Owner: panif_user
--

CREATE TABLE public.workflows_tags (
    "workflowId" character varying(36) NOT NULL,
    "tagId" character varying(36) NOT NULL
);


ALTER TABLE public.workflows_tags OWNER TO panif_user;

--
-- Name: auth_provider_sync_history id; Type: DEFAULT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.auth_provider_sync_history ALTER COLUMN id SET DEFAULT nextval('public.auth_provider_sync_history_id_seq'::regclass);


--
-- Name: clientes id_cliente; Type: DEFAULT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.clientes ALTER COLUMN id_cliente SET DEFAULT nextval('public.clientes_id_cliente_seq'::regclass);


--
-- Name: detalle_pedidos id_detalle; Type: DEFAULT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.detalle_pedidos ALTER COLUMN id_detalle SET DEFAULT nextval('public.detalle_pedidos_id_detalle_seq'::regclass);


--
-- Name: deudas id_deuda; Type: DEFAULT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.deudas ALTER COLUMN id_deuda SET DEFAULT nextval('public.deudas_id_deuda_seq'::regclass);


--
-- Name: execution_annotations id; Type: DEFAULT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.execution_annotations ALTER COLUMN id SET DEFAULT nextval('public.execution_annotations_id_seq'::regclass);


--
-- Name: execution_entity id; Type: DEFAULT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.execution_entity ALTER COLUMN id SET DEFAULT nextval('public.execution_entity_id_seq'::regclass);


--
-- Name: execution_metadata id; Type: DEFAULT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.execution_metadata ALTER COLUMN id SET DEFAULT nextval('public.execution_metadata_temp_id_seq'::regclass);


--
-- Name: migrations id; Type: DEFAULT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.migrations ALTER COLUMN id SET DEFAULT nextval('public.migrations_id_seq'::regclass);


--
-- Name: pagos id_pago; Type: DEFAULT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.pagos ALTER COLUMN id_pago SET DEFAULT nextval('public.pagos_id_pago_seq'::regclass);


--
-- Name: pedidos id_pedido; Type: DEFAULT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.pedidos ALTER COLUMN id_pedido SET DEFAULT nextval('public.pedidos_id_pedido_seq'::regclass);


--
-- Name: produccion_diaria id_produccion; Type: DEFAULT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.produccion_diaria ALTER COLUMN id_produccion SET DEFAULT nextval('public.produccion_diaria_id_produccion_seq'::regclass);


--
-- Name: productos id_producto; Type: DEFAULT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.productos ALTER COLUMN id_producto SET DEFAULT nextval('public.productos_id_producto_seq'::regclass);


--
-- Name: recetas_masa id_receta; Type: DEFAULT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.recetas_masa ALTER COLUMN id_receta SET DEFAULT nextval('public.recetas_masa_id_receta_seq'::regclass);


--
-- Name: topings id_toping; Type: DEFAULT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.topings ALTER COLUMN id_toping SET DEFAULT nextval('public.topings_id_toping_seq'::regclass);


--
-- Name: usuarios id_usuario; Type: DEFAULT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.usuarios ALTER COLUMN id_usuario SET DEFAULT nextval('public.usuarios_id_usuario_seq'::regclass);


--
-- Name: usuarios_dashboard id; Type: DEFAULT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.usuarios_dashboard ALTER COLUMN id SET DEFAULT nextval('public.usuarios_dashboard_id_seq'::regclass);


--
-- Name: workflow_statistics id; Type: DEFAULT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.workflow_statistics ALTER COLUMN id SET DEFAULT nextval('public.workflow_statistics_id_seq'::regclass);


--
-- Data for Name: annotation_tag_entity; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.annotation_tag_entity (id, name, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: auth_identity; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.auth_identity ("userId", "providerId", "providerType", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: auth_provider_sync_history; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.auth_provider_sync_history (id, "providerType", "runMode", status, "startedAt", "endedAt", scanned, created, updated, disabled, error) FROM stdin;
\.


--
-- Data for Name: binary_data; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.binary_data ("fileId", "sourceType", "sourceId", data, "mimeType", "fileName", "fileSize", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: chat_hub_agent_tools; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.chat_hub_agent_tools ("agentId", "toolId") FROM stdin;
\.


--
-- Data for Name: chat_hub_agents; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.chat_hub_agents (id, name, description, "systemPrompt", "ownerId", "credentialId", provider, model, "createdAt", "updatedAt", icon, files, "suggestedPrompts") FROM stdin;
\.


--
-- Data for Name: chat_hub_messages; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.chat_hub_messages (id, "sessionId", "previousMessageId", "revisionOfMessageId", "retryOfMessageId", type, name, content, provider, model, "workflowId", "executionId", "createdAt", "updatedAt", "agentId", status, attachments) FROM stdin;
\.


--
-- Data for Name: chat_hub_session_tools; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.chat_hub_session_tools ("sessionId", "toolId") FROM stdin;
\.


--
-- Data for Name: chat_hub_sessions; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.chat_hub_sessions (id, title, "ownerId", "lastMessageAt", "credentialId", provider, model, "workflowId", "createdAt", "updatedAt", "agentId", "agentName") FROM stdin;
\.


--
-- Data for Name: chat_hub_tools; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.chat_hub_tools (id, name, type, "typeVersion", "ownerId", definition, enabled, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: clientes; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.clientes (id_cliente, telegram_id, nombre_negocio, telefono, direccion, contacto_principal, categoria, estado, fecha_registro) FROM stdin;
1	\N	911	\N	\N	\N	restaurante	activo	2026-04-26 16:03:54.360128
2	\N	A Y V COMIDA CHINA	\N	\N	\N	restaurante	activo	2026-04-26 16:03:54.360128
3	\N	AHUMADITOS	\N	\N	\N	restaurante	activo	2026-04-26 16:03:54.360128
4	\N	AHUMADOS GRILL	\N	\N	\N	restaurante	activo	2026-04-26 16:03:54.360128
5	\N	ANTOJOS BELENSATE	\N	\N	\N	restaurante	activo	2026-04-26 16:03:54.360128
6	\N	BE FIT	\N	\N	\N	cafeteria	activo	2026-04-26 16:03:54.360128
7	\N	BOCADOS CONGELADOS	\N	\N	\N	otro	activo	2026-04-26 16:03:54.360128
8	\N	BODEGON EL MARQUEZ	\N	\N	\N	restaurante	activo	2026-04-26 16:03:54.360128
9	\N	BON APPETIT BURGER	\N	\N	\N	restaurante	activo	2026-04-26 16:03:54.360128
10	\N	BURGER GRILL	\N	\N	\N	restaurante	activo	2026-04-26 16:03:54.360128
11	\N	BURGER HOUSE	\N	\N	\N	restaurante	activo	2026-04-26 16:03:54.360128
12	\N	CABAÑA BISTRO	\N	\N	\N	restaurante	activo	2026-04-26 16:03:54.360128
13	\N	CAZZO PIZZA	\N	\N	\N	restaurante	activo	2026-04-26 16:03:54.360128
14	\N	CESAR SANCHEZ	\N	\N	\N	otro	activo	2026-04-26 16:03:54.360128
15	\N	CHELOS BURGER	\N	\N	\N	restaurante	activo	2026-04-26 16:03:54.360128
16	\N	CHEO BURGER	\N	\N	\N	restaurante	activo	2026-04-26 16:03:54.360128
17	\N	CHINESSE	\N	\N	\N	restaurante	activo	2026-04-26 16:03:54.360128
18	\N	COLD BREW	\N	\N	\N	cafeteria	activo	2026-04-26 16:03:54.360128
19	\N	DAHAUS	\N	\N	\N	restaurante	activo	2026-04-26 16:03:54.360128
20	\N	DANOVA	\N	\N	\N	restaurante	activo	2026-04-26 16:03:54.360128
21	\N	DAVID COMBY	\N	\N	\N	otro	activo	2026-04-26 16:03:54.360128
22	\N	DISFRUPARK	\N	\N	\N	otro	activo	2026-04-26 16:03:54.360128
23	\N	EBERT MATTIE	\N	\N	\N	restaurante	activo	2026-04-26 16:03:54.360128
24	\N	LM MARKET CC ALTO CHAMA	\N	\N	\N	market	activo	2026-04-26 16:03:54.360128
25	@luisepm92	PRUEBA	3218821223	\N	\N	restaurante	activo	2026-04-26 20:20:15.769424
27	\N	ALEXANDRA BLANCO	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
28	\N	BANDIII BAR	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
29	\N	CLARET ARIAS	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
30	\N	EDEN BISTRO	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
31	\N	FRESH BURGER	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
32	\N	FRIGORIFICO LALA	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
33	\N	GINAS CAFE	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
34	\N	HIPERMERCADO SHANGHAI	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
35	\N	HOTEL CONVENCION BOUTIQUE	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
36	\N	HOTEL VENETUR	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
37	\N	IN HOUSE	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
38	\N	JC BAR'S	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
39	\N	JHON LA CREMA	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
40	\N	JONATHAN BARRIOS	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
41	\N	JOSE MILLAN	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
42	\N	JUMPARK	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
43	\N	LA CREMA JR	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
44	\N	LA CREMITA	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
45	\N	LA CUESTA FOOD	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
46	\N	LEXUS	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
47	\N	LISBETH LOPEZ	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
48	\N	LM MARKETS FACTURAS	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
49	\N	LM MARKET LAS AMERICAS	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
50	\N	LM MARKET TOVAR	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
51	\N	LONCHERA GRILL	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
52	\N	LUCIANO ROMANO	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
53	\N	LUMIERE	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
54	\N	MC. BETO	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
55	\N	MERIDA GRILL	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
56	\N	MONTAÑAS FACTURAS	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
57	\N	MONTAÑA BROASTER	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
58	\N	MONTAÑA GRILL	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
59	\N	O'SOLEMIO	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
60	\N	OASIS BAR	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
61	\N	PABLO DUGARTE	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
62	\N	PAPITAS	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
63	\N	PICOS BURGER	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
64	\N	PIZZARITOS	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
65	\N	REST. ALMA MIA	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
66	\N	SALVADOR RAMIREZ	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
67	\N	SAMUEL DELICATESES	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
68	\N	SANTA CRISTINA CAFETERIA	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
69	\N	SANTO PECADO	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
70	\N	SILVANOS	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
71	\N	SALARE REST.	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
72	\N	THE PLACE 818	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
73	\N	TOSTAOS	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
74	\N	YANTAR	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
75	\N	YON ROSS	\N	\N	\N	otro	activo	2026-07-04 18:33:46.868878
\.


--
-- Data for Name: credentials_entity; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.credentials_entity (name, data, type, "createdAt", "updatedAt", id, "isManaged", "isGlobal", "isResolvable", "resolvableAllowFallback", "resolverId") FROM stdin;
\.


--
-- Data for Name: data_table; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.data_table (id, name, "projectId", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: data_table_column; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.data_table_column (id, name, type, index, "dataTableId", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: detalle_pedidos; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.detalle_pedidos (id_detalle, id_pedido, tipo_pan, producto, peso_g, cantidad, tipo_unidad, precio_unitario, subtotal, toping) FROM stdin;
\.


--
-- Data for Name: deudas; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.deudas (id_deuda, id_cliente, id_pedido, monto_original, monto_pagado, estado, fecha_creacion, fecha_vencimiento, descripcion) FROM stdin;
\.


--
-- Data for Name: dynamic_credential_entry; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.dynamic_credential_entry (credential_id, subject_id, resolver_id, data, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: dynamic_credential_resolver; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.dynamic_credential_resolver (id, name, type, config, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: dynamic_credential_user_entry; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.dynamic_credential_user_entry ("credentialId", "userId", "resolverId", data, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: event_destinations; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.event_destinations (id, destination, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: execution_annotation_tags; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.execution_annotation_tags ("annotationId", "tagId") FROM stdin;
\.


--
-- Data for Name: execution_annotations; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.execution_annotations (id, "executionId", vote, note, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: execution_data; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.execution_data ("executionId", "workflowData", data, "workflowVersionId") FROM stdin;
\.


--
-- Data for Name: execution_entity; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.execution_entity (id, finished, mode, "retryOf", "retrySuccessId", "startedAt", "stoppedAt", "waitTill", status, "workflowId", "deletedAt", "createdAt", "storedAt") FROM stdin;
\.


--
-- Data for Name: execution_metadata; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.execution_metadata (id, "executionId", key, value) FROM stdin;
\.


--
-- Data for Name: folder; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.folder (id, name, "parentFolderId", "projectId", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: folder_tag; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.folder_tag ("folderId", "tagId") FROM stdin;
\.


--
-- Data for Name: insights_by_period; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.insights_by_period (id, "metaId", type, value, "periodUnit", "periodStart") FROM stdin;
\.


--
-- Data for Name: insights_metadata; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.insights_metadata ("metaId", "workflowId", "projectId", "workflowName", "projectName") FROM stdin;
\.


--
-- Data for Name: insights_raw; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.insights_raw (id, "metaId", type, value, "timestamp") FROM stdin;
\.


--
-- Data for Name: installed_nodes; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.installed_nodes (name, type, "latestVersion", package) FROM stdin;
\.


--
-- Data for Name: installed_packages; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.installed_packages ("packageName", "installedVersion", "authorName", "authorEmail", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: invalid_auth_token; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.invalid_auth_token (token, "expiresAt") FROM stdin;
\.


--
-- Data for Name: migrations; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.migrations (id, "timestamp", name) FROM stdin;
1	1587669153312	InitialMigration1587669153312
2	1589476000887	WebhookModel1589476000887
3	1594828256133	CreateIndexStoppedAt1594828256133
4	1607431743768	MakeStoppedAtNullable1607431743768
5	1611144599516	AddWebhookId1611144599516
6	1617270242566	CreateTagEntity1617270242566
7	1620824779533	UniqueWorkflowNames1620824779533
8	1626176912946	AddwaitTill1626176912946
9	1630419189837	UpdateWorkflowCredentials1630419189837
10	1644422880309	AddExecutionEntityIndexes1644422880309
11	1646834195327	IncreaseTypeVarcharLimit1646834195327
12	1646992772331	CreateUserManagement1646992772331
13	1648740597343	LowerCaseUserEmail1648740597343
14	1652254514002	CommunityNodes1652254514002
15	1652367743993	AddUserSettings1652367743993
16	1652905585850	AddAPIKeyColumn1652905585850
17	1654090467022	IntroducePinData1654090467022
18	1658932090381	AddNodeIds1658932090381
19	1659902242948	AddJsonKeyPinData1659902242948
20	1660062385367	CreateCredentialsUserRole1660062385367
21	1663755770893	CreateWorkflowsEditorRole1663755770893
22	1664196174001	WorkflowStatistics1664196174001
23	1665484192212	CreateCredentialUsageTable1665484192212
24	1665754637025	RemoveCredentialUsageTable1665754637025
25	1669739707126	AddWorkflowVersionIdColumn1669739707126
26	1669823906995	AddTriggerCountColumn1669823906995
27	1671535397530	MessageEventBusDestinations1671535397530
28	1671726148421	RemoveWorkflowDataLoadedFlag1671726148421
29	1673268682475	DeleteExecutionsWithWorkflows1673268682475
30	1674138566000	AddStatusToExecutions1674138566000
31	1674509946020	CreateLdapEntities1674509946020
32	1675940580449	PurgeInvalidWorkflowConnections1675940580449
33	1676996103000	MigrateExecutionStatus1676996103000
34	1677236854063	UpdateRunningExecutionStatus1677236854063
35	1677501636754	CreateVariables1677501636754
36	1679416281778	CreateExecutionMetadataTable1679416281778
37	1681134145996	AddUserActivatedProperty1681134145996
38	1681134145997	RemoveSkipOwnerSetup1681134145997
39	1690000000000	MigrateIntegerKeysToString1690000000000
40	1690000000020	SeparateExecutionData1690000000020
41	1690000000030	RemoveResetPasswordColumns1690000000030
42	1690000000030	AddMfaColumns1690000000030
43	1690787606731	AddMissingPrimaryKeyOnExecutionData1690787606731
44	1691088862123	CreateWorkflowNameIndex1691088862123
45	1692967111175	CreateWorkflowHistoryTable1692967111175
46	1693491613982	ExecutionSoftDelete1693491613982
47	1693554410387	DisallowOrphanExecutions1693554410387
48	1694091729095	MigrateToTimestampTz1694091729095
49	1695128658538	AddWorkflowMetadata1695128658538
50	1695829275184	ModifyWorkflowHistoryNodesAndConnections1695829275184
51	1700571993961	AddGlobalAdminRole1700571993961
52	1705429061930	DropRoleMapping1705429061930
53	1711018413374	RemoveFailedExecutionStatus1711018413374
54	1711390882123	MoveSshKeysToDatabase1711390882123
55	1712044305787	RemoveNodesAccess1712044305787
56	1714133768519	CreateProject1714133768519
57	1714133768521	MakeExecutionStatusNonNullable1714133768521
58	1717498465931	AddActivatedAtUserSetting1717498465931
59	1720101653148	AddConstraintToExecutionMetadata1720101653148
60	1721377157740	FixExecutionMetadataSequence1721377157740
61	1723627610222	CreateInvalidAuthTokenTable1723627610222
62	1723796243146	RefactorExecutionIndices1723796243146
63	1724753530828	CreateAnnotationTables1724753530828
64	1724951148974	AddApiKeysTable1724951148974
65	1726606152711	CreateProcessedDataTable1726606152711
66	1727427440136	SeparateExecutionCreationFromStart1727427440136
67	1728659839644	AddMissingPrimaryKeyOnAnnotationTagMapping1728659839644
68	1729607673464	UpdateProcessedDataValueColumnToText1729607673464
69	1729607673469	AddProjectIcons1729607673469
70	1730386903556	CreateTestDefinitionTable1730386903556
71	1731404028106	AddDescriptionToTestDefinition1731404028106
72	1731582748663	MigrateTestDefinitionKeyToString1731582748663
73	1732271325258	CreateTestMetricTable1732271325258
74	1732549866705	CreateTestRun1732549866705
75	1733133775640	AddMockedNodesColumnToTestDefinition1733133775640
76	1734479635324	AddManagedColumnToCredentialsTable1734479635324
77	1736172058779	AddStatsColumnsToTestRun1736172058779
78	1736947513045	CreateTestCaseExecutionTable1736947513045
79	1737715421462	AddErrorColumnsToTestRuns1737715421462
80	1738709609940	CreateFolderTable1738709609940
81	1739549398681	CreateAnalyticsTables1739549398681
82	1740445074052	UpdateParentFolderIdColumn1740445074052
83	1741167584277	RenameAnalyticsToInsights1741167584277
84	1742918400000	AddScopesColumnToApiKeys1742918400000
85	1745322634000	ClearEvaluation1745322634000
86	1745587087521	AddWorkflowStatisticsRootCount1745587087521
87	1745934666076	AddWorkflowArchivedColumn1745934666076
88	1745934666077	DropRoleTable1745934666077
89	1747824239000	AddProjectDescriptionColumn1747824239000
90	1750252139166	AddLastActiveAtColumnToUser1750252139166
91	1750252139166	AddScopeTables1750252139166
92	1750252139167	AddRolesTables1750252139167
93	1750252139168	LinkRoleToUserTable1750252139168
94	1750252139170	RemoveOldRoleColumn1750252139170
95	1752669793000	AddInputsOutputsToTestCaseExecution1752669793000
96	1753953244168	LinkRoleToProjectRelationTable1753953244168
97	1754475614601	CreateDataStoreTables1754475614601
98	1754475614602	ReplaceDataStoreTablesWithDataTables1754475614602
99	1756906557570	AddTimestampsToRoleAndRoleIndexes1756906557570
100	1758731786132	AddAudienceColumnToApiKeys1758731786132
101	1758794506893	AddProjectIdToVariableTable1758794506893
102	1759399811000	ChangeValueTypesForInsights1759399811000
103	1760019379982	CreateChatHubTables1760019379982
104	1760020000000	CreateChatHubAgentTable1760020000000
105	1760020838000	UniqueRoleNames1760020838000
106	1760116750277	CreateOAuthEntities1760116750277
107	1760314000000	CreateWorkflowDependencyTable1760314000000
108	1760965142113	DropUnusedChatHubColumns1760965142113
109	1761047826451	AddWorkflowVersionColumn1761047826451
110	1761655473000	ChangeDependencyInfoToJson1761655473000
111	1761773155024	AddAttachmentsToChatHubMessages1761773155024
112	1761830340990	AddToolsColumnToChatHubTables1761830340990
113	1762177736257	AddWorkflowDescriptionColumn1762177736257
114	1762763704614	BackfillMissingWorkflowHistoryRecords1762763704614
115	1762771264000	ChangeDefaultForIdInUserTable1762771264000
116	1762771954619	AddIsGlobalColumnToCredentialsTable1762771954619
117	1762847206508	AddWorkflowHistoryAutoSaveFields1762847206508
118	1763047800000	AddActiveVersionIdColumn1763047800000
119	1763048000000	ActivateExecuteWorkflowTriggerWorkflows1763048000000
120	1763572724000	ChangeOAuthStateColumnToUnboundedVarchar1763572724000
121	1763716655000	CreateBinaryDataTable1763716655000
122	1764167920585	CreateWorkflowPublishHistoryTable1764167920585
123	1764276827837	AddCreatorIdToProjectTable1764276827837
124	1764682447000	CreateDynamicCredentialResolverTable1764682447000
125	1764689388394	AddDynamicCredentialEntryTable1764689388394
126	1765448186933	BackfillMissingWorkflowHistoryRecords1765448186933
127	1765459448000	AddResolvableFieldsToCredentials1765459448000
128	1765788427674	AddIconToAgentTable1765788427674
129	1765804780000	ConvertAgentIdToUuid1765804780000
130	1765886667897	AddAgentIdForeignKeys1765886667897
131	1765892199653	AddWorkflowVersionIdToExecutionData1765892199653
132	1766064542000	AddWorkflowPublishScopeToProjectRoles1766064542000
133	1766068346315	AddChatMessageIndices1766068346315
134	1766500000000	ExpandInsightsWorkflowIdLength1766500000000
135	1767018516000	ChangeWorkflowStatisticsFKToNoAction1767018516000
136	1768402473068	ExpandModelColumnLength1768402473068
137	1768557000000	AddStoredAtToExecutionEntity1768557000000
138	1768901721000	AddDynamicCredentialUserEntryTable1768901721000
139	1769000000000	AddPublishedVersionIdToWorkflowDependency1769000000000
140	1769433700000	CreateSecretsProviderConnectionTables1769433700000
141	1769698710000	CreateWorkflowPublishedVersionTable1769698710000
142	1769784356000	ExpandSubjectIDColumnLength1769784356000
143	1769900001000	AddWorkflowUnpublishScopeToCustomRoles1769900001000
144	1770000000000	CreateChatHubToolsTable1770000000000
145	1770000000000	ExpandProviderIdColumnLength1770000000000
146	1770220686000	CreateWorkflowBuilderSessionTable1770220686000
147	1771417407753	AddScalingFieldsToTestRun1771417407753
148	1771500000000	MigrateExternalSecretsToEntityStorage1771500000000
149	1771500000001	AddUnshareScopeToCustomRoles1771500000001
150	1771500000002	AddFilesColumnToChatHubAgents1771500000002
151	1772000000000	AddSuggestedPromptsToAgentTable1772000000000
152	1772619247761	AddRoleColumnToProjectSecretsProviderAccess1772619247761
\.


--
-- Data for Name: oauth_access_tokens; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.oauth_access_tokens (token, "clientId", "userId") FROM stdin;
\.


--
-- Data for Name: oauth_authorization_codes; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.oauth_authorization_codes (code, "clientId", "userId", "redirectUri", "codeChallenge", "codeChallengeMethod", "expiresAt", state, used, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: oauth_clients; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.oauth_clients (id, name, "redirectUris", "grantTypes", "clientSecret", "clientSecretExpiresAt", "tokenEndpointAuthMethod", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: oauth_refresh_tokens; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.oauth_refresh_tokens (token, "clientId", "userId", "expiresAt", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: oauth_user_consents; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.oauth_user_consents (id, "userId", "clientId", "grantedAt") FROM stdin;
\.


--
-- Data for Name: pagos; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.pagos (id_pago, id_deuda, id_cliente, monto_pagado, fecha_pago, metodo, registrado_por, notas) FROM stdin;
\.


--
-- Data for Name: pedidos; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.pedidos (id_pedido, id_cliente, numero_recibo, fecha_pedido, fecha_entrega, estado, monto_total, archivo_pdf_url, observaciones, registrado_por, fecha_produccion_requerida, fecha_despacho_real, confirmado_por_admin, fecha_confirmacion_admin, despacho_confirmado, fecha_confirmacion_despacho, monto_delivery, aplica_iva) FROM stdin;
\.


--
-- Data for Name: processed_data; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.processed_data ("workflowId", context, "createdAt", "updatedAt", value) FROM stdin;
\.


--
-- Data for Name: produccion_diaria; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.produccion_diaria (id_produccion, fecha_produccion, tipo_pan, producto, peso_g, total_unidades, peso_total_g, estado, fecha_produccion_requerida, cliente, id_pedido) FROM stdin;
\.


--
-- Data for Name: productos; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.productos (id_producto, nombre, tipo_masa, tipo_pan, peso_g, precio_unitario, paquete_cantidad, paquete_tipo, descripcion, activo, fecha_creacion, fecha_ultima_modificacion) FROM stdin;
2	Masa Francesa Paninis 125g	FRANCESA	PANINIS	125	3.10	8	unidades	\N	t	2026-04-29 18:12:32.632657	2026-04-29 18:12:32.632657
4	Masa Sobada Hamburguesa 75g	SOBADA	HAMBURGUESA	75	1.80	6	unidades	\N	t	2026-04-29 18:12:32.632657	2026-04-29 18:12:32.632657
8	Masa de Mantequilla Hamburguesa 95g	MANTEQUILLA	HAMBURGUESA	95	3.60	6	unidades	\N	t	2026-04-29 18:12:32.632657	2026-04-29 18:12:32.632657
9	Masa Brioche Hamburguesa 95g	BRIOCHE	HAMBURGUESA	95	3.80	6	unidades	\N	t	2026-04-29 18:12:32.632657	2026-04-29 18:12:32.632657
13	Pan Basico Hamburguesa 85g	BASICA	HAMBURGUESA	85	1.80	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
19	Pan Basico Hamburguesa 155g	BASICA	HAMBURGUESA	155	3.00	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
20	Pan Basico Perro Mediano 45g	BASICA	PERRO	45	2.00	16	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
21	Pan Basico Mini Hamburgesa 25g	BASICA	HAMBURGUESA	25	1.70	10	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
22	Pan Basico Perro Mediano 55g	BASICA	PERRO	55	1.20	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
25	Masa Francesa canilla 220g	FRANCESA	CANILLA	220	0.70	1	unidad	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
26	Masa Francesa Sub 180g	FRANCESA	SUB	180	3.80	5	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
27	Masa estandar Hamburguesa de 55g	ESTANDAR	HAMBURGUESA	55	1.90	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
28	Masa estandar Hamburguesa de 75g	ESTANDAR	HAMBURGUESA	75	1.90	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
29	Masa estandar Hamburguesa de 85g	ESTANDAR	HAMBURGUESA	85	2.10	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
30	Masa estandar Hamburguesa de 105g	ESTANDAR	HAMBURGUESA	105	2.30	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
31	Masa Sobada Hamburguesa de 55g	SOBADA	HAMBURGUESA	55	1.80	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
32	Masa Sobada Hamburguesa de 65g	SOBADA	HAMBURGUESA	65	2.50	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
33	Masa Sobada Hamburguesa de 75g	SOBADA	HAMBURGUESA	75	1.80	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
34	Masa Sobada Hamburguesa de 95g	SOBADA	HAMBURGUESA	95	2.50	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
35	Masa Sobada Hamburgesa de 125g	SOBADA	HAMBURGUESA	125	3.20	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
36	Masa Sobada Paninis 85g	SOBADA	PANINIS	85	3.90	10	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
37	Masa Sobada Perro caliente grande de 75g	SOBADA	PERRO	75	3.30	12	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
39	Masa Sobada Perro caliente Mediano de 55g	SOBADA	PERRO	55	3.50	16	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
40	Masa Sobada Perro 65g	SOBADA	PERRO	65	3.00	12	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
42	Masa Sobada Banquete de 15g	SOBADA	BANQUETE	15	1.60	15	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
43	Masa Sobada Paninis 125g	SOBADA	PANINIS	125	5.00	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
44	Masa Sobada Paninis 135g	SOBADA	PANINIS	135	3.00	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
45	Pan de Hamburguesa Edicion Halloween	SOBADA	HALLOWEEN	\N	3.00	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
46	Pan de Hamburguesa Edicion Halloween (P)	SOBADA	HALLOWEEN	\N	3.00	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
47	Masa abriochada Mini hamburguesa de 25g	ABRIOCHADA	HAMBURGUESA	25	2.00	10	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
48	Masa abriochada Mini hamburguesa de 45g	ABRIOCHADA	HAMBURGUESA	45	1.90	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
49	Masa abriochada Hamburguesa de 55g	ABRIOCHADA	HAMBURGUESA	55	2.30	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
50	Masa abriochada hamburguesa de 65g	ABRIOCHADA	HAMBURGUESA	65	2.20	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
52	Masa abriochada Hamburguesa de 85g	ABRIOCHADA	HAMBURGUESA	85	2.40	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
53	Masa abriochada Hamburguesa de 85gr	ABRIOCHADA	HAMBURGUESA	85	2.60	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
54	Masa abriochada Hamburguesa de 95g	ABRIOCHADA	HAMBURGUESA	95	2.50	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
55	Masa abriochada Hamburguesa de 95g (e a)	ABRIOCHADA	HAMBURGUESA	95	2.70	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
56	Masa abriochada Hamburguesa de 105g	ABRIOCHADA	HAMBURGUESA	105	2.60	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
57	Masa abriochada Hamburguesa de 105g (e a)	ABRIOCHADA	HAMBURGUESA	105	2.80	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
58	Masa abriochada Hamburguesa de 115g	ABRIOCHADA	HAMBURGUESA	115	2.80	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
59	Masa abriochada Hamburguesa de 115g (e a)	ABRIOCHADA	HAMBURGUESA	115	3.00	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
51	Masa abriochada Hamburguesa de 75g	ABRIOCHADA	HAMBURGUESA	90	2.30	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-07-04 15:36:12.382168
6	Masa de Papa Hamburguesa 95g	PAPA	HAMBURGUESA	110	3.30	6	unidades	\N	t	2026-04-29 18:12:32.632657	2026-07-04 15:39:06.326082
7	Masa de Batata Hamburguesa 95g	BATATA	HAMBURGUESA	110	3.30	6	unidades	\N	t	2026-04-29 18:12:32.632657	2026-07-15 16:14:37.342782
1	Pan Básico Hamburguesa 85g	BASICA	HAMBURGUESA	85	1.80	6	unidades	\N	f	2026-04-29 18:12:32.632657	2026-04-29 18:12:32.632657
60	Masa abriochada Choripanes de 65g	ABRIOCHADA	CHORIPAN	65	3.30	10	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
61	Masa abriochada Choriperros de 75g	ABRIOCHADA	PERRO	75	3.80	10	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
62	Masa abriochada Perros de 75g 3Bolitas	ABRIOCHADA	PERRO	75	3.90	10	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
63	Masa abriochada Perro caliente Mediano 65g	ABRIOCHADA	PERRO	65	5.20	16	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
64	Masa Abriochada Mini HB 35g	ABRIOCHADA	HAMBURGUESA	35	2.50	10	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
66	Masa de Papa Hamburguesa de 95g (e)	PAPA	HAMBURGUESA	95	3.00	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
67	Masa de Papa Hamburguesa de 65g	PAPA	HAMBURGUESA	65	3.30	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
68	Masa de Papa Hamburguesa de 55g	PAPA	HAMBURGUESA	55	3.20	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
69	Masa de Papa Hamburguesa de 115g	PAPA	HAMBURGUESA	115	3.90	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
70	Masa de Papa Choripan 75g	PAPA	CHORIPAN	75	4.40	10	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
71	Masa Papa Perro G 75g	PAPA	PERRO	75	5.50	12	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
72	Masa Papa Perro G 75g (M.M)	PAPA	PERRO	75	4.80	12	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
73	Masa de Papa Mini HB 40g	PAPA	HAMBURGUESA	40	3.30	10	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
74	Masa de Papa Hamburguesa de 105g	PAPA	HAMBURGUESA	105	3.60	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
75	Masa de Papa Perro M de 55g	PAPA	PERRO	55	5.50	16	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
76	Masa de batata Perro  3B	BATATA	PERRO	\N	4.00	10	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
77	Masa de batata Perro  3 Bolitas (M.M)	BATATA	PERRO	\N	2.70	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
78	Masa de Batata perro 3 Bolitas	BATATA	PERRO	\N	4.40	10	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
79	Masa de Batata perro 75g	BATATA	PERRO	75	5.50	12	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
80	Masa de Batata perro 45g	BATATA	PERRO	45	4.30	14	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
81	Masa de Batata Perro Mediano 55g	BATATA	PERRO	55	5.50	16	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
82	Masa de Batata Hamburguesa de 95g	BATATA	HAMBURGUESA	95	3.30	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
83	Masa de Batata Hamburguesa de 95g (M.M)	BATATA	HAMBURGUESA	95	2.80	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
85	Masa de Batata Mini Hamburguesa 25g	BATATA	HAMBURGUESA	25	3.30	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
86	Masa de Batata Hamburguesa de 115g	BATATA	HAMBURGUESA	115	3.90	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
87	Masa de Batata Hamburguesa de 105g	BATATA	HAMBURGUESA	105	3.60	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
88	Masa de Mantequilla Hamburguesa de 95g	MANTEQUILLA	HAMBURGUESA	95	3.60	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
89	Masa de Mantequilla Hamburguesa de 55g	MANTEQUILLA	HAMBURGUESA	55	3.50	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
90	Masa de Mantequilla Hamburguesa de 65g	MANTEQUILLA	HAMBURGUESA	65	3.60	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
91	Masa de Mantequilla pan de queso	MANTEQUILLA	PAN_QUESO	\N	7.00	1	unidad	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
92	Masa Brioche Hamburguesa de 95g	BRIOCHE	HAMBURGUESA	95	3.80	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
94	Masa Brioche Hamburguesa de 75g	BRIOCHE	HAMBURGUESA	75	3.20	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
95	Masa Brioche Hamburguesa de 65g	BRIOCHE	HAMBURGUESA	65	3.50	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
97	Masa Brioche Panini 120g	BRIOCHE	PANINIS	120	5.60	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
98	Masa Brioche Hamburguesa de 25	BRIOCHE	HAMBURGUESA	25	3.00	10	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
99	Masa Brioche Perro caliente Grande de 90g	BRIOCHE	PERRO	90	6.30	12	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
100	Masa Brioche Hamburguesa de 45g	BRIOCHE	HAMBURGUESA	45	2.70	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
101	Masa Brioche Choripan 65g	BRIOCHE	CHORIPAN	65	4.70	10	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
102	Hojaldradas Croissant Buns 130g	HOJALDRADA	CROISSANT	130	6.60	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
103	Hojaldradas Croissant tradicional grande 130g	HOJALDRADA	CROISSANT	130	4.40	4	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
104	Hojaldradas Croissant tradicional mediano 80g	HOJALDRADA	CROISSANT	80	4.40	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
106	Hojaldradas Croissant margarina mediano 60g	HOJALDRADA	CROISSANT	60	4.60	10	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
107	Hojaldradas Croissant margarina mediano (E) 60g	HOJALDRADA	CROISSANT	60	2.50	10	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
109	Hojaldradas Palmeritas con chocolates	HOJALDRADA	PALMERITAS	\N	4.00	10	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
110	Croissant 470g	HOJALDRADA	CROISSANT	470	4.40	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
65	Masa de Papa Hamburguesa de 95g	PAPA	HAMBURGUESA	110	3.30	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-07-04 15:39:25.508232
84	Masa de Batata Hamburguesa de 55g	BATATA	HAMBURGUESA	70	3.30	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-07-15 16:03:14.897802
93	Masa Brioche Hamburguesa de 85g	BRIOCHE	HAMBURGUESA	100	3.50	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-07-15 17:01:39.711442
96	Masa Brioche Hamburguesa de 55g	BRIOCHE	HAMBURGUESA	70	3.10	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-07-15 17:02:19.533286
111	Afrecho Mantequilla y Miel	AFRECHO_MANT_MIEL	SANDWICH	\N	4.50	\N	\N	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
112	Afrecho Avena y Pasas	AFRECHO_MANT_MIEL	SANDWICH	\N	3.00	\N	\N	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
113	Afrecho Zanahoria y Avena	AFRECHO_MANT_MIEL	SANDWICH	\N	3.00	\N	\N	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
105	Hojaldradas Croissant tradicional pequeno 30g	HOJALDRADA	CROISSANT	30	4.40	12	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
108	Hojaldradas Palmeritas clasicas	HOJALDRADA	PALMERITAS	\N	4.00	12	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
122	Pan Hamburguesa Papa 570g	PAPA	HAMBURGUESA	570	3.00	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
123	Pan Hamburguesa Papa 440gg	PAPA	HAMBURGUESA	440	3.00	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
124	Pan de Hamburguesa Batata 570g	BATATA	HAMBURGUESA	570	3.00	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
125	Pan de Hamburguesa Batata 440g	BATATA	HAMBURGUESA	440	3.00	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
126	Pan de Hamburguesa Brioche 570g	BRIOCHE	HAMBURGUESA	570	3.40	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
127	Pan de Hamburguesa Brioche 440g	BRIOCHE	HAMBURGUESA	440	3.40	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
128	Pan de Hamburguesa Basico 570g	BASICA	HAMBURGUESA	570	1.80	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
129	Pan de Hamburguesa Basico 440g	BASICA	HAMBURGUESA	440	1.80	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
130	Pan de Hamburguesa Mantequilla 570g	MANTEQUILLA	HAMBURGUESA	570	3.30	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
131	Pan de Hamburguesa Mantequilla 440g	MANTEQUILLA	HAMBURGUESA	440	3.30	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
132	Pan de Perro Papa 640g	PAPA	PERRO	640	3.30	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
133	Pan de Perro Papa 520g	PAPA	PERRO	520	2.40	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
134	Pan de Perro Batata 640g	BATATA	PERRO	640	3.30	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
135	Pan de Perro Batata 520g	BATATA	PERRO	520	2.40	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
136	Pan de Perro Basico 640g	BASICA	PERRO	640	1.40	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
137	Pan de Perro Basico 520g	BASICA	PERRO	520	1.20	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
138	Pan Sandwich Batata 720g	BATATA	SANDWICH	720	4.00	1	unidad	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
14	Pan Basico Hamburguesa de 95g	BASICA	HAMBURGUESA	95	1.80	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
15	Pan Basico Hamburguesa de 105g	BASICA	HAMBURGUESA	105	2.00	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
16	Pan Basico Hamburguesa de 115g	BASICA	HAMBURGUESA	115	2.30	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
5	Masa Abriochada Hamburguesa 75g	ABRIOCHADA	HAMBURGUESA	90	2.30	6	unidades	\N	t	2026-04-29 18:12:32.632657	2026-07-04 15:35:38.664953
115	pan de hamburguesa afrecho mantequilla y miel	AFRECHO_MANT_MIEL	HAMBURGUESA	\N	3.20	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
3	Masa Estandar Hamburguesa 75g	ESTANDAR	HAMBURGUESA	75	1.90	6	unidades	\N	t	2026-04-29 18:12:32.632657	2026-04-29 18:12:32.632657
10	Pan Basico Hamburguesa de 55g	BASICA	HAMBURGUESA	55	1.70	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
11	Pan Basico Hamburguesa de 45g	BASICA	HAMBURGUESA	45	1.50	8	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
12	Pan Basico Hamburguesa de 75g	BASICA	HAMBURGUESA	75	1.70	6	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
18	Pan Basico Perro caliente Mediano de 55g	BASICA	PERRO	55	2.30	16	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
24	Masa Francesa Choripan de 65g	FRANCESA	CHORIPAN	65	2.50	10	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
38	Masa Sobada Perro caliente pequeno de 45g	SOBADA	PERRO	45	2.80	14	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
41	Masa Sobada Choripan de 65g	SOBADA	CHORIPAN	65	2.90	10	unidades	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
17	Pan Basico Perro caliente Grande de 75g	BASICA	PERRO	90	2.30	12	unidades	\N	t	2026-04-29 18:13:55.716322	2026-07-15 17:03:58.521461
139	Sandwich blanco Grande	BASICA	SANDWICH	\N	3.00	\N	\N	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
140	Sandwich blanco Pequeno	BASICA	SANDWICH	\N	1.70	\N	\N	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
121	Sandwich en masa Brioche	BRIOCHE	SANDWICH	\N	4.70	\N	\N	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
117	Sandwich en masa de Batata	BATATA	SANDWICH	\N	4.60	\N	\N	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
118	Sandwich en masa de Batata (M.M)	BATATA	SANDWICH	\N	4.10	\N	\N	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
120	Sandwich en masa de Mantequilla	MANTEQUILLA	SANDWICH	\N	5.30	\N	\N	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
116	Sandwich en masa de Papa	PAPA	SANDWICH	\N	4.60	\N	\N	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
119	Sandwich en masa de Papa (M.M)	PAPA	SANDWICH	\N	4.10	\N	\N	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
114	Basico de Afrecho y Pasas	AFRECHO_MANT_MIEL	SANDWICH	\N	2.00	\N	\N	\N	t	2026-04-29 18:13:55.716322	2026-04-29 18:13:55.716322
\.


--
-- Data for Name: project; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.project (id, name, type, "createdAt", "updatedAt", icon, description, "creatorId") FROM stdin;
a9Vqx61mvDbNFLaD	Unnamed Project	personal	2026-04-26 16:04:10.659+00	2026-04-26 16:04:10.659+00	\N	\N	6e0e5e92-e7d5-45a6-9ba3-de8c62bf1b5f
\.


--
-- Data for Name: project_relation; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.project_relation ("projectId", "userId", role, "createdAt", "updatedAt") FROM stdin;
a9Vqx61mvDbNFLaD	6e0e5e92-e7d5-45a6-9ba3-de8c62bf1b5f	project:personalOwner	2026-04-26 16:04:10.659+00	2026-04-26 16:04:10.659+00
\.


--
-- Data for Name: project_secrets_provider_access; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.project_secrets_provider_access ("secretsProviderConnectionId", "projectId", "createdAt", "updatedAt", role) FROM stdin;
\.


--
-- Data for Name: recetas_masa; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.recetas_masa (id_receta, tipo_masa, ingrediente, cantidad_por_kg_masa, unidad) FROM stdin;
37	BASICA_LM	HARINA	0.4579	kg
38	BASICA_LM	AZUCAR	0.0275	kg
39	BASICA_LM	SAL	0.0092	kg
40	BASICA_LM	CONSERVANTE	0.0037	kg
41	BASICA_LM	MANTECA	0.0137	kg
42	BASICA_LM	MARGARINA	0.0275	kg
43	BASICA_LM	HUEVO	0.0229	kg
44	BASICA_LM	ESENCIA VAINILLA	0.0046	kg
45	BASICA_LM	LEVADURA	0.0027	kg
46	BASICA_LM	HIELO	0.1259	kg
47	BASICA_LM	AGUA	0.2518	kg
48	BASICA_LM	PIE	0.0458	kg
49	BASICA_LM	S-500	0.0069	kg
50	FRANCESA	HARINA	0.4557	kg
51	FRANCESA	AZUCAR	0.0364	kg
52	FRANCESA	SAL	0.0091	kg
53	FRANCESA	CONSERVANTE	0.0014	kg
54	FRANCESA	MANTECA	0.0547	kg
55	FRANCESA	ESENCIA MANTEQUILLA	0.0023	kg
56	FRANCESA	LEVADURA	0.0023	kg
57	FRANCESA	HIELO	0.1640	kg
58	FRANCESA	AGUA	0.2733	kg
59	FRANCESA	EMULSIPAN	0.0009	kg
60	ESTANDAR	HARINA	0.4842	kg
61	ESTANDAR	AZUCAR	0.0387	kg
62	ESTANDAR	SAL	0.0073	kg
63	ESTANDAR	CONSERVANTE	0.0015	kg
64	ESTANDAR	MANTECA	0.0339	kg
65	ESTANDAR	ESENCIA VAINILLA	0.0024	kg
66	ESTANDAR	LEVADURA	0.0024	kg
67	ESTANDAR	HIELO	0.1428	kg
68	ESTANDAR	AGUA	0.2857	kg
69	ESTANDAR	EMULSIPAN	0.0010	kg
70	SOBADA	HARINA	0.4904	kg
71	SOBADA	AZUCAR	0.0441	kg
72	SOBADA	SAL	0.0074	kg
73	SOBADA	CONSERVANTE	0.0015	kg
74	SOBADA	MANTECA	0.0294	kg
75	SOBADA	ESENCIA VAINILLA	0.0039	kg
76	SOBADA	LEVADURA	0.0029	kg
77	SOBADA	HIELO	0.1398	kg
78	SOBADA	AGUA	0.2796	kg
79	SOBADA	EMULSIPAN	0.0010	kg
80	SOBADA_PE	HARINA	0.4943	kg
81	SOBADA_PE	AZUCAR	0.0445	kg
82	SOBADA_PE	SAL	0.0074	kg
83	SOBADA_PE	CONSERVANTE	0.0015	kg
84	SOBADA_PE	MANTECA	0.0297	kg
85	SOBADA_PE	ESENCIA VAINILLA	0.0040	kg
86	SOBADA_PE	LEVADURA	0.0025	kg
87	SOBADA_PE	HIELO	0.1384	kg
88	SOBADA_PE	AGUA	0.2769	kg
89	SOBADA_PE	EMULSIPAN	0.0010	kg
90	SOBADA_PA	HARINA	0.5018	kg
91	SOBADA_PA	AZUCAR	0.0251	kg
92	SOBADA_PA	SAL	0.0075	kg
93	SOBADA_PA	CONSERVANTE	0.0015	kg
94	SOBADA_PA	MANTECA	0.0301	kg
95	SOBADA_PA	ESENCIA VAINILLA	0.0015	kg
96	SOBADA_PA	LEVADURA	0.1003	kg
97	SOBADA_PA	HIELO	0.1405	kg
98	SOBADA_PA	AGUA	0.2810	kg
99	SOBADA_PA	EMULSIPAN	0.0010	kg
114	PAPA	HARINA	0.4771	kg
115	PAPA	AZUCAR	0.0429	kg
116	PAPA	SAL	0.0119	kg
117	PAPA	CONSERVANTE	0.0029	kg
118	PAPA	MANTECA	0.0167	kg
119	PAPA	MARGARINA	0.0334	kg
120	PAPA	HUEVO	0.0716	kg
121	PAPA	ESENCIA MANTEQUILLA	0.0048	kg
122	PAPA	LEVADURA	0.0014	kg
123	PAPA	PURE DE PAPA	0.2863	kg
124	PAPA	AGUA	0.0501	kg
125	PAPA	EMULSIPAN	0.0010	kg
126	PAPA_LM	HARINA	0.4733	kg
127	PAPA_LM	AZUCAR	0.0426	kg
128	PAPA_LM	SAL	0.0118	kg
129	PAPA_LM	CONSERVANTE	0.0047	kg
130	PAPA_LM	MANTECA	0.0166	kg
131	PAPA_LM	MARGARINA	0.0331	kg
132	PAPA_LM	HUEVO	0.0710	kg
133	PAPA_LM	ESENCIA MANTEQUILLA	0.0047	kg
134	PAPA_LM	LEVADURA	0.0014	kg
111	ABRIOCHADA	AGUA	0.1184	kg
101	ABRIOCHADA	AZUCAR	0.0503	kg
108	ABRIOCHADA	ESENCIA NATA	0.0014	kg
107	ABRIOCHADA	ESENCIA MANTEQUILLA	0.0014	kg
103	ABRIOCHADA	CONSERVANTE	0.0017	kg
100	ABRIOCHADA	HARINA	0.5583	kg
105	ABRIOCHADA	MARGARINA	0.0223	kg
109	ABRIOCHADA	LEVADURA	0.0045	kg
110	ABRIOCHADA	HIELO	0.1776	kg
106	ABRIOCHADA	HUEVO	0.0279	kg
104	ABRIOCHADA	MANTECA	0.0223	kg
102	ABRIOCHADA	SAL	0.0084	kg
27	BASICA	CONSERVANTE	0.0032	kg
24	BASICA	HARINA	0.5371	kg
33	BASICA	HIELO	0.1477	kg
25	BASICA	AZUCAR	0.0322	kg
31	BASICA	ESENCIA VAINILLA	0.0054	kg
34	BASICA	AGUA	0.1477	kg
30	BASICA	HUEVO	0.0269	kg
32	BASICA	LEVADURA	0.0032	kg
29	BASICA	MARGARINA	0.0161	kg
28	BASICA	MANTECA	0.0161	kg
35	BASICA	PIE	0.0537	kg
26	BASICA	SAL	0.0107	kg
135	PAPA_LM	PURE DE PAPA	0.2840	kg
136	PAPA_LM	AGUA	0.0497	kg
137	PAPA_LM	S-500	0.0071	kg
150	BATATA_LM	HARINA	0.4332	kg
151	BATATA_LM	AZUCAR	0.0303	kg
152	BATATA_LM	SAL	0.0087	kg
153	BATATA_LM	CONSERVANTE	0.0043	kg
154	BATATA_LM	MANTECA	0.0152	kg
155	BATATA_LM	MARGARINA	0.0303	kg
156	BATATA_LM	HUEVO	0.0650	kg
157	BATATA_LM	ESENCIA NATA	0.0043	kg
158	BATATA_LM	LEVADURA	0.0013	kg
159	BATATA_LM	PURE DE BATATA	0.3552	kg
160	BATATA_LM	AGUA	0.0455	kg
161	BATATA_LM	S-500	0.0065	kg
162	MANTEQUILLA	HARINA	0.4823	kg
163	MANTEQUILLA	AZUCAR	0.0289	kg
164	MANTEQUILLA	SAL	0.0096	kg
165	MANTEQUILLA	CONSERVANTE	0.0014	kg
166	MANTEQUILLA	MANTEQUILLA_ING	0.0772	kg
167	MANTEQUILLA	HUEVO	0.0723	kg
168	MANTEQUILLA	ESENCIA MANTEQUILLA	0.0058	kg
169	MANTEQUILLA	LEVADURA	0.0029	kg
170	MANTEQUILLA	LECHE	0.0096	kg
171	MANTEQUILLA	COLOR AMARILLO	0.0001	kg
172	MANTEQUILLA	HIELO	0.1158	kg
173	MANTEQUILLA	AGUA	0.1930	kg
174	MANTEQUILLA	EMULSIPAN	0.0010	kg
175	MANTEQUILLA_LM	HARINA	0.4786	kg
176	MANTEQUILLA_LM	AZUCAR	0.0287	kg
177	MANTEQUILLA_LM	SAL	0.0096	kg
178	MANTEQUILLA_LM	CONSERVANTE	0.0029	kg
179	MANTEQUILLA_LM	MANTEQUILLA_ING	0.0766	kg
180	MANTEQUILLA_LM	HUEVO	0.0718	kg
181	MANTEQUILLA_LM	ESENCIA MANTEQUILLA	0.0057	kg
182	MANTEQUILLA_LM	LEVADURA	0.0029	kg
183	MANTEQUILLA_LM	LECHE	0.0096	kg
184	MANTEQUILLA_LM	COLOR AMARILLO	0.0001	kg
185	MANTEQUILLA_LM	HIELO	0.1149	kg
186	MANTEQUILLA_LM	AGUA	0.1915	kg
187	MANTEQUILLA_LM	S-500	0.0072	kg
202	BRIOCHE_LM	HARINA	0.4762	kg
203	BRIOCHE_LM	AZUCAR	0.0714	kg
204	BRIOCHE_LM	SAL	0.0095	kg
205	BRIOCHE_LM	CONSERVANTE	0.0029	kg
206	BRIOCHE_LM	MARGARINA	0.0476	kg
207	BRIOCHE_LM	MANTEQUILLA_ING	0.0190	kg
208	BRIOCHE_LM	HUEVO	0.0714	kg
209	BRIOCHE_LM	ESENCIA MANTEQUILLA	0.0048	kg
210	BRIOCHE_LM	LEVADURA	0.0129	kg
211	BRIOCHE_LM	LECHE	0.0095	kg
212	BRIOCHE_LM	HIELO	0.1000	kg
213	BRIOCHE_LM	AGUA	0.1667	kg
214	BRIOCHE_LM	EMULSIPAN	0.0010	kg
215	BRIOCHE_LM	S-500	0.0071	kg
216	HOJALDRADA	HARINA	0.4662	kg
217	HOJALDRADA	AZUCAR	0.0093	kg
218	HOJALDRADA	SAL	0.0047	kg
219	HOJALDRADA	CONSERVANTE	0.0014	kg
220	HOJALDRADA	MARGARINA	0.0932	kg
221	HOJALDRADA	AGUA	0.2378	kg
222	HOJALDRADA	EMULSIPAN	0.0009	kg
223	HOJALDRADA	EMPASTE MANTEQUILLA	0.1865	kg
224	CROISSANTS	HARINA	0.4152	kg
225	CROISSANTS	AZUCAR	0.0374	kg
226	CROISSANTS	SAL	0.0062	kg
227	CROISSANTS	CONSERVANTE	0.0012	kg
228	CROISSANTS	MANTECA	0.0166	kg
229	CROISSANTS	MARGARINA	0.0166	kg
230	CROISSANTS	HUEVO	0.0208	kg
231	CROISSANTS	ESENCIA MANTEQUILLA	0.0010	kg
232	CROISSANTS	ESENCIA NATA	0.0010	kg
233	CROISSANTS	LEVADURA	0.0021	kg
234	CROISSANTS	HIELO	0.1038	kg
235	CROISSANTS	AGUA	0.2077	kg
236	CROISSANTS	EMULSIPAN	0.0042	kg
237	CROISSANTS	EMPASTE MANTEQUILLA	0.1661	kg
238	CROISSANTS_SEMI	HARINA	0.4269	kg
239	CROISSANTS_SEMI	AZUCAR	0.0384	kg
240	CROISSANTS_SEMI	SAL	0.0064	kg
241	CROISSANTS_SEMI	CONSERVANTE	0.0013	kg
242	CROISSANTS_SEMI	MANTECA	0.0171	kg
243	CROISSANTS_SEMI	MARGARINA	0.0341	kg
244	CROISSANTS_SEMI	HUEVO	0.0213	kg
245	CROISSANTS_SEMI	ESENCIA MANTEQUILLA	0.0011	kg
246	CROISSANTS_SEMI	ESENCIA NATA	0.0021	kg
247	CROISSANTS_SEMI	LEVADURA	0.0021	kg
248	CROISSANTS_SEMI	HIELO	0.1067	kg
249	CROISSANTS_SEMI	AGUA	0.2135	kg
250	CROISSANTS_SEMI	EMULSIPAN	0.0009	kg
251	CROISSANTS_SEMI	EMPASTE MARGARINA	0.1281	kg
252	AFRECHO_MANT_MIEL	HARINA	0.4016	kg
253	AFRECHO_MANT_MIEL	AZUCAR	0.0201	kg
254	AFRECHO_MANT_MIEL	SAL	0.0100	kg
255	AFRECHO_MANT_MIEL	CONSERVANTE	0.0012	kg
256	AFRECHO_MANT_MIEL	MANTEQUILLA_ING	0.0402	kg
257	AFRECHO_MANT_MIEL	HUEVO	0.0803	kg
258	AFRECHO_MANT_MIEL	LEVADURA	0.0040	kg
259	AFRECHO_MANT_MIEL	LECHE	0.0080	kg
260	AFRECHO_MANT_MIEL	MIEL	0.0402	kg
142	BATATA	MANTECA	0.0155	kg
148	BATATA	AGUA	0.0464	kg
147	BATATA	PURE DE BATATA	0.3622	kg
146	BATATA	LEVADURA	0.0013	kg
140	BATATA	SAL	0.0088	kg
191	BRIOCHE	CONSERVANTE	0.0016	kg
194	BRIOCHE	HUEVO	0.0798	kg
144	BATATA	HUEVO	0.0663	kg
143	BATATA	MARGARINA	0.0155	kg
188	BRIOCHE	HARINA	0.5319	kg
195	BRIOCHE	ESENCIA MANTEQUILLA	0.0053	kg
197	BRIOCHE	LECHE	0.0106	kg
198	BRIOCHE	HIELO	0.1117	kg
196	BRIOCHE	LEVADURA	0.0144	kg
201	BRIOCHE	S-500	0.0053	kg
189	BRIOCHE	AZUCAR	0.0798	kg
190	BRIOCHE	SAL	0.0106	kg
192	BRIOCHE	MARGARINA	0.0532	kg
199	BRIOCHE	AGUA	0.0745	kg
261	AFRECHO_MANT_MIEL	AFRECHO	0.0803	kg
262	AFRECHO_MANT_MIEL	HIELO	0.1044	kg
263	AFRECHO_MANT_MIEL	AGUA	0.2088	kg
264	AFRECHO_MANT_MIEL	EMULSIPAN	0.0008	kg
265	ABRIOCHADA	PURATOS	0.0056	kg
139	BATATA	AZUCAR	0.0309	kg
138	BATATA	HARINA	0.4417	kg
145	BATATA	ESENCIA NATA	0.0044	kg
141	BATATA	CONSERVANTE	0.0027	kg
266	BATATA	S-500	0.0044	kg
267	BRIOCHE	MANTEQUILLA	0.0213	kg
268	BASICA	S-500	0.0053	kg
\.


--
-- Data for Name: role; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.role (slug, "displayName", description, "roleType", "systemRole", "createdAt", "updatedAt") FROM stdin;
global:chatUser	Chat User	Chat User	global	t	2026-04-26 16:04:12.124+00	2026-04-26 16:04:12.124+00
global:owner	Owner	Owner	global	t	2026-04-26 16:04:11.368+00	2026-04-26 16:04:12.185+00
global:admin	Admin	Admin	global	t	2026-04-26 16:04:11.368+00	2026-04-26 16:04:12.185+00
global:member	Member	Member	global	t	2026-04-26 16:04:11.368+00	2026-04-26 16:04:12.186+00
project:admin	Project Admin	Full control of settings, members, workflows, credentials and executions	project	t	2026-04-26 16:04:11.368+00	2026-04-26 16:04:12.216+00
project:personalOwner	Project Owner	Project Owner	project	t	2026-04-26 16:04:11.368+00	2026-04-26 16:04:12.216+00
project:editor	Project Editor	Create, edit, and delete workflows, credentials, and executions	project	t	2026-04-26 16:04:11.368+00	2026-04-26 16:04:12.216+00
project:viewer	Project Viewer	Read-only access to workflows, credentials, and executions	project	t	2026-04-26 16:04:11.368+00	2026-04-26 16:04:12.216+00
project:chatUser	Project Chat User	Chat-only access to chatting with workflows that have n8n Chat enabled	project	t	2026-04-26 16:04:11.368+00	2026-04-26 16:04:12.216+00
credential:owner	Credential Owner	Credential Owner	credential	t	2026-04-26 16:04:12.124+00	2026-04-26 16:04:12.124+00
credential:user	Credential User	Credential User	credential	t	2026-04-26 16:04:12.124+00	2026-04-26 16:04:12.124+00
workflow:owner	Workflow Owner	Workflow Owner	workflow	t	2026-04-26 16:04:12.124+00	2026-04-26 16:04:12.124+00
workflow:editor	Workflow Editor	Workflow Editor	workflow	t	2026-04-26 16:04:12.124+00	2026-04-26 16:04:12.124+00
\.


--
-- Data for Name: role_scope; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.role_scope ("roleSlug", "scopeSlug") FROM stdin;
global:owner	workflow:unshare
global:owner	credential:unshare
global:owner	aiAssistant:manage
global:owner	annotationTag:create
global:owner	annotationTag:read
global:owner	annotationTag:update
global:owner	annotationTag:delete
global:owner	annotationTag:list
global:owner	auditLogs:manage
global:owner	banner:dismiss
global:owner	community:register
global:owner	communityPackage:install
global:owner	communityPackage:uninstall
global:owner	communityPackage:update
global:owner	communityPackage:list
global:owner	credential:share
global:owner	credential:shareGlobally
global:owner	credential:move
global:owner	credential:create
global:owner	credential:read
global:owner	credential:update
global:owner	credential:delete
global:owner	credential:list
global:owner	externalSecretsProvider:sync
global:owner	externalSecretsProvider:create
global:owner	externalSecretsProvider:read
global:owner	externalSecretsProvider:update
global:owner	externalSecretsProvider:delete
global:owner	externalSecretsProvider:list
global:owner	externalSecret:list
global:owner	eventBusDestination:test
global:owner	eventBusDestination:create
global:owner	eventBusDestination:read
global:owner	eventBusDestination:update
global:owner	eventBusDestination:delete
global:owner	eventBusDestination:list
global:owner	ldap:sync
global:owner	ldap:manage
global:owner	license:manage
global:owner	logStreaming:manage
global:owner	orchestration:read
global:owner	project:create
global:owner	project:read
global:owner	project:update
global:owner	project:delete
global:owner	project:list
global:owner	saml:manage
global:owner	securityAudit:generate
global:owner	securitySettings:manage
global:owner	sourceControl:pull
global:owner	sourceControl:push
global:owner	sourceControl:manage
global:owner	tag:create
global:owner	tag:read
global:owner	tag:update
global:owner	tag:delete
global:owner	tag:list
global:owner	user:resetPassword
global:owner	user:changeRole
global:owner	user:enforceMfa
global:owner	user:generateInviteLink
global:owner	user:create
global:owner	user:read
global:owner	user:update
global:owner	user:delete
global:owner	user:list
global:owner	variable:create
global:owner	variable:read
global:owner	variable:update
global:owner	variable:delete
global:owner	variable:list
global:owner	projectVariable:create
global:owner	projectVariable:read
global:owner	projectVariable:update
global:owner	projectVariable:delete
global:owner	projectVariable:list
global:owner	workersView:manage
global:owner	workflow:share
global:owner	workflow:execute
global:owner	workflow:execute-chat
global:owner	workflow:move
global:owner	workflow:updateRedactionSetting
global:owner	workflow:create
global:owner	workflow:read
global:owner	workflow:update
global:owner	workflow:delete
global:owner	workflow:list
global:owner	folder:create
global:owner	folder:read
global:owner	folder:update
global:owner	folder:delete
global:owner	folder:list
global:owner	folder:move
global:owner	insights:list
global:owner	oidc:manage
global:owner	provisioning:manage
global:owner	dataTable:create
global:owner	dataTable:read
global:owner	dataTable:update
global:owner	dataTable:delete
global:owner	dataTable:list
global:owner	dataTable:readRow
global:owner	dataTable:writeRow
global:owner	dataTable:listProject
global:owner	execution:reveal
global:owner	role:manage
global:owner	mcp:manage
global:owner	mcp:oauth
global:owner	mcpApiKey:create
global:owner	mcpApiKey:rotate
global:owner	chatHub:manage
global:owner	chatHub:message
global:owner	chatHubAgent:create
global:owner	chatHubAgent:read
global:owner	chatHubAgent:update
global:owner	chatHubAgent:delete
global:owner	chatHubAgent:list
global:owner	breakingChanges:list
global:owner	apiKey:manage
global:owner	credentialResolver:create
global:owner	credentialResolver:read
global:owner	credentialResolver:update
global:owner	credentialResolver:delete
global:owner	credentialResolver:list
global:owner	workflow:publish
global:admin	workflow:unshare
global:admin	credential:unshare
global:admin	aiAssistant:manage
global:admin	annotationTag:create
global:admin	annotationTag:read
global:admin	annotationTag:update
global:admin	annotationTag:delete
global:admin	annotationTag:list
global:admin	auditLogs:manage
global:admin	banner:dismiss
global:admin	community:register
global:admin	communityPackage:install
global:admin	communityPackage:uninstall
global:admin	communityPackage:update
global:admin	communityPackage:list
global:admin	credential:share
global:admin	credential:shareGlobally
global:admin	credential:move
global:admin	credential:create
global:admin	credential:read
global:admin	credential:update
global:admin	credential:delete
global:admin	credential:list
global:admin	externalSecretsProvider:sync
global:admin	externalSecretsProvider:create
global:admin	externalSecretsProvider:read
global:admin	externalSecretsProvider:update
global:admin	externalSecretsProvider:delete
global:admin	externalSecretsProvider:list
global:admin	externalSecret:list
global:admin	eventBusDestination:test
global:admin	eventBusDestination:create
global:admin	eventBusDestination:read
global:admin	eventBusDestination:update
global:admin	eventBusDestination:delete
global:admin	eventBusDestination:list
global:admin	ldap:sync
global:admin	ldap:manage
global:admin	license:manage
global:admin	logStreaming:manage
global:admin	orchestration:read
global:admin	project:create
global:admin	project:read
global:admin	project:update
global:admin	project:delete
global:admin	project:list
global:admin	saml:manage
global:admin	securityAudit:generate
global:admin	securitySettings:manage
global:admin	sourceControl:pull
global:admin	sourceControl:push
global:admin	sourceControl:manage
global:admin	tag:create
global:admin	tag:read
global:admin	tag:update
global:admin	tag:delete
global:admin	tag:list
global:admin	user:resetPassword
global:admin	user:changeRole
global:admin	user:enforceMfa
global:admin	user:generateInviteLink
global:admin	user:create
global:admin	user:read
global:admin	user:update
global:admin	user:delete
global:admin	user:list
global:admin	variable:create
global:admin	variable:read
global:admin	variable:update
global:admin	variable:delete
global:admin	variable:list
global:admin	projectVariable:create
global:admin	projectVariable:read
global:admin	projectVariable:update
global:admin	projectVariable:delete
global:admin	projectVariable:list
global:admin	workersView:manage
global:admin	workflow:share
global:admin	workflow:execute
global:admin	workflow:execute-chat
global:admin	workflow:move
global:admin	workflow:updateRedactionSetting
global:admin	workflow:create
global:admin	workflow:read
global:admin	workflow:update
global:admin	workflow:delete
global:admin	workflow:list
global:admin	folder:create
global:admin	folder:read
global:admin	folder:update
global:admin	folder:delete
global:admin	folder:list
global:admin	folder:move
global:admin	insights:list
global:admin	oidc:manage
global:admin	provisioning:manage
global:admin	dataTable:create
global:admin	dataTable:read
global:admin	dataTable:update
global:admin	dataTable:delete
global:admin	dataTable:list
global:admin	dataTable:readRow
global:admin	dataTable:writeRow
global:admin	dataTable:listProject
global:admin	execution:reveal
global:admin	role:manage
global:admin	mcp:manage
global:admin	mcp:oauth
global:admin	mcpApiKey:create
global:admin	mcpApiKey:rotate
global:admin	chatHub:manage
global:admin	chatHub:message
global:admin	chatHubAgent:create
global:admin	chatHubAgent:read
global:admin	chatHubAgent:update
global:admin	chatHubAgent:delete
global:admin	chatHubAgent:list
global:admin	breakingChanges:list
global:admin	apiKey:manage
global:admin	credentialResolver:create
global:admin	credentialResolver:read
global:admin	credentialResolver:update
global:admin	credentialResolver:delete
global:admin	credentialResolver:list
global:admin	workflow:publish
global:member	annotationTag:create
global:member	annotationTag:read
global:member	annotationTag:update
global:member	annotationTag:delete
global:member	annotationTag:list
global:member	eventBusDestination:test
global:member	eventBusDestination:list
global:member	tag:create
global:member	tag:read
global:member	tag:update
global:member	tag:list
global:member	user:list
global:member	variable:read
global:member	variable:list
global:member	dataTable:list
global:member	mcp:oauth
global:member	mcpApiKey:create
global:member	mcpApiKey:rotate
global:member	chatHub:message
global:member	chatHubAgent:create
global:member	chatHubAgent:read
global:member	chatHubAgent:update
global:member	chatHubAgent:delete
global:member	chatHubAgent:list
global:member	apiKey:manage
global:member	credentialResolver:list
global:chatUser	chatHub:message
global:chatUser	chatHubAgent:create
global:chatUser	chatHubAgent:read
global:chatUser	chatHubAgent:update
global:chatUser	chatHubAgent:delete
global:chatUser	chatHubAgent:list
project:admin	workflow:unpublish
project:admin	credential:unshare
project:admin	credential:share
project:admin	credential:move
project:admin	credential:create
project:admin	credential:read
project:admin	credential:update
project:admin	credential:delete
project:admin	credential:list
project:admin	project:read
project:admin	project:update
project:admin	project:delete
project:admin	project:list
project:admin	sourceControl:push
project:admin	projectVariable:create
project:admin	projectVariable:read
project:admin	projectVariable:update
project:admin	projectVariable:delete
project:admin	projectVariable:list
project:admin	workflow:execute
project:admin	workflow:execute-chat
project:admin	workflow:move
project:admin	workflow:updateRedactionSetting
project:admin	workflow:create
project:admin	workflow:read
project:admin	workflow:update
project:admin	workflow:delete
project:admin	workflow:list
project:admin	folder:create
project:admin	folder:read
project:admin	folder:update
project:admin	folder:delete
project:admin	folder:list
project:admin	folder:move
project:admin	dataTable:create
project:admin	dataTable:read
project:admin	dataTable:update
project:admin	dataTable:delete
project:admin	dataTable:readRow
project:admin	dataTable:writeRow
project:admin	dataTable:listProject
project:admin	execution:reveal
project:admin	workflow:publish
project:personalOwner	workflow:unpublish
project:personalOwner	workflow:unshare
project:personalOwner	credential:unshare
project:personalOwner	credential:share
project:personalOwner	credential:move
project:personalOwner	credential:create
project:personalOwner	credential:read
project:personalOwner	credential:update
project:personalOwner	credential:delete
project:personalOwner	credential:list
project:personalOwner	project:read
project:personalOwner	project:list
project:personalOwner	workflow:share
project:personalOwner	workflow:execute
project:personalOwner	workflow:execute-chat
project:personalOwner	workflow:move
project:personalOwner	workflow:updateRedactionSetting
project:personalOwner	workflow:create
project:personalOwner	workflow:read
project:personalOwner	workflow:update
project:personalOwner	workflow:delete
project:personalOwner	workflow:list
project:personalOwner	folder:create
project:personalOwner	folder:read
project:personalOwner	folder:update
project:personalOwner	folder:delete
project:personalOwner	folder:list
project:personalOwner	folder:move
project:personalOwner	dataTable:create
project:personalOwner	dataTable:read
project:personalOwner	dataTable:update
project:personalOwner	dataTable:delete
project:personalOwner	dataTable:readRow
project:personalOwner	dataTable:writeRow
project:personalOwner	dataTable:listProject
project:personalOwner	execution:reveal
project:personalOwner	workflow:publish
project:editor	workflow:unpublish
project:editor	credential:create
project:editor	credential:read
project:editor	credential:update
project:editor	credential:delete
project:editor	credential:list
project:editor	project:read
project:editor	project:list
project:editor	projectVariable:create
project:editor	projectVariable:read
project:editor	projectVariable:update
project:editor	projectVariable:delete
project:editor	projectVariable:list
project:editor	workflow:execute
project:editor	workflow:execute-chat
project:editor	workflow:create
project:editor	workflow:read
project:editor	workflow:update
project:editor	workflow:delete
project:editor	workflow:list
project:editor	folder:create
project:editor	folder:read
project:editor	folder:update
project:editor	folder:delete
project:editor	folder:list
project:editor	dataTable:create
project:editor	dataTable:read
project:editor	dataTable:update
project:editor	dataTable:delete
project:editor	dataTable:readRow
project:editor	dataTable:writeRow
project:editor	dataTable:listProject
project:editor	workflow:publish
project:viewer	credential:read
project:viewer	credential:list
project:viewer	project:read
project:viewer	project:list
project:viewer	projectVariable:read
project:viewer	projectVariable:list
project:viewer	workflow:execute-chat
project:viewer	workflow:read
project:viewer	workflow:list
project:viewer	folder:read
project:viewer	folder:list
project:viewer	dataTable:read
project:viewer	dataTable:readRow
project:viewer	dataTable:listProject
project:chatUser	workflow:execute-chat
credential:owner	credential:unshare
credential:owner	credential:share
credential:owner	credential:move
credential:owner	credential:read
credential:owner	credential:update
credential:owner	credential:delete
credential:user	credential:read
workflow:owner	workflow:unpublish
workflow:owner	workflow:unshare
workflow:owner	workflow:share
workflow:owner	workflow:execute
workflow:owner	workflow:execute-chat
workflow:owner	workflow:move
workflow:owner	workflow:read
workflow:owner	workflow:update
workflow:owner	workflow:delete
workflow:owner	workflow:publish
workflow:editor	workflow:unpublish
workflow:editor	workflow:execute
workflow:editor	workflow:execute-chat
workflow:editor	workflow:read
workflow:editor	workflow:update
workflow:editor	workflow:publish
\.


--
-- Data for Name: scope; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.scope (slug, "displayName", description) FROM stdin;
workflow:unpublish	Unpublish Workflow	Allows unpublishing workflows.
workflow:unshare	Unshare Workflow	Allows removing workflow shares.
credential:unshare	Unshare Credential	Allows removing credential shares.
aiAssistant:manage	Manage AI Usage	Allows managing AI Usage settings.
aiAssistant:*	aiAssistant:*	\N
annotationTag:create	Create Annotation Tag	Allows creating new annotation tags.
annotationTag:read	annotationTag:read	\N
annotationTag:update	annotationTag:update	\N
annotationTag:delete	annotationTag:delete	\N
annotationTag:list	annotationTag:list	\N
annotationTag:*	annotationTag:*	\N
auditLogs:manage	auditLogs:manage	\N
auditLogs:*	auditLogs:*	\N
banner:dismiss	banner:dismiss	\N
banner:*	banner:*	\N
community:register	community:register	\N
community:*	community:*	\N
communityPackage:install	communityPackage:install	\N
communityPackage:uninstall	communityPackage:uninstall	\N
communityPackage:update	communityPackage:update	\N
communityPackage:list	communityPackage:list	\N
communityPackage:manage	communityPackage:manage	\N
communityPackage:*	communityPackage:*	\N
credential:share	credential:share	\N
credential:shareGlobally	credential:shareGlobally	\N
credential:move	credential:move	\N
credential:create	credential:create	\N
credential:read	credential:read	\N
credential:update	credential:update	\N
credential:delete	credential:delete	\N
credential:list	credential:list	\N
credential:*	credential:*	\N
externalSecretsProvider:sync	externalSecretsProvider:sync	\N
externalSecretsProvider:create	externalSecretsProvider:create	\N
externalSecretsProvider:read	externalSecretsProvider:read	\N
externalSecretsProvider:update	externalSecretsProvider:update	\N
externalSecretsProvider:delete	externalSecretsProvider:delete	\N
externalSecretsProvider:list	externalSecretsProvider:list	\N
externalSecretsProvider:*	externalSecretsProvider:*	\N
externalSecret:list	externalSecret:list	\N
externalSecret:*	externalSecret:*	\N
eventBusDestination:test	eventBusDestination:test	\N
eventBusDestination:create	eventBusDestination:create	\N
eventBusDestination:read	eventBusDestination:read	\N
eventBusDestination:update	eventBusDestination:update	\N
eventBusDestination:delete	eventBusDestination:delete	\N
eventBusDestination:list	eventBusDestination:list	\N
eventBusDestination:*	eventBusDestination:*	\N
ldap:sync	ldap:sync	\N
ldap:manage	ldap:manage	\N
ldap:*	ldap:*	\N
license:manage	license:manage	\N
license:*	license:*	\N
logStreaming:manage	logStreaming:manage	\N
logStreaming:*	logStreaming:*	\N
orchestration:read	orchestration:read	\N
orchestration:list	orchestration:list	\N
orchestration:*	orchestration:*	\N
project:create	project:create	\N
project:read	project:read	\N
project:update	project:update	\N
project:delete	project:delete	\N
project:list	project:list	\N
project:*	project:*	\N
saml:manage	saml:manage	\N
saml:*	saml:*	\N
securityAudit:generate	securityAudit:generate	\N
securityAudit:*	securityAudit:*	\N
securitySettings:manage	securitySettings:manage	\N
securitySettings:*	securitySettings:*	\N
sourceControl:pull	sourceControl:pull	\N
sourceControl:push	sourceControl:push	\N
sourceControl:manage	sourceControl:manage	\N
sourceControl:*	sourceControl:*	\N
tag:create	tag:create	\N
tag:read	tag:read	\N
tag:update	tag:update	\N
tag:delete	tag:delete	\N
tag:list	tag:list	\N
tag:*	tag:*	\N
user:resetPassword	user:resetPassword	\N
user:changeRole	user:changeRole	\N
user:enforceMfa	user:enforceMfa	\N
user:generateInviteLink	user:generateInviteLink	\N
user:create	user:create	\N
user:read	user:read	\N
user:update	user:update	\N
user:delete	user:delete	\N
user:list	user:list	\N
user:*	user:*	\N
variable:create	variable:create	\N
variable:read	variable:read	\N
variable:update	variable:update	\N
variable:delete	variable:delete	\N
variable:list	variable:list	\N
variable:*	variable:*	\N
projectVariable:create	projectVariable:create	\N
projectVariable:read	projectVariable:read	\N
projectVariable:update	projectVariable:update	\N
projectVariable:delete	projectVariable:delete	\N
projectVariable:list	projectVariable:list	\N
projectVariable:*	projectVariable:*	\N
workersView:manage	workersView:manage	\N
workersView:*	workersView:*	\N
workflow:share	workflow:share	\N
workflow:execute	workflow:execute	\N
workflow:execute-chat	workflow:execute-chat	\N
workflow:move	workflow:move	\N
workflow:activate	workflow:activate	\N
workflow:deactivate	workflow:deactivate	\N
workflow:updateRedactionSetting	workflow:updateRedactionSetting	\N
workflow:create	workflow:create	\N
workflow:read	workflow:read	\N
workflow:update	workflow:update	\N
workflow:delete	workflow:delete	\N
workflow:list	workflow:list	\N
workflow:*	workflow:*	\N
folder:create	folder:create	\N
folder:read	folder:read	\N
folder:update	folder:update	\N
folder:delete	folder:delete	\N
folder:list	folder:list	\N
folder:move	folder:move	\N
folder:*	folder:*	\N
insights:list	insights:list	\N
insights:*	insights:*	\N
oidc:manage	oidc:manage	\N
oidc:*	oidc:*	\N
provisioning:manage	provisioning:manage	\N
provisioning:*	provisioning:*	\N
dataTable:create	dataTable:create	\N
dataTable:read	dataTable:read	\N
dataTable:update	dataTable:update	\N
dataTable:delete	dataTable:delete	\N
dataTable:list	dataTable:list	\N
dataTable:readRow	dataTable:readRow	\N
dataTable:writeRow	dataTable:writeRow	\N
dataTable:listProject	dataTable:listProject	\N
dataTable:*	dataTable:*	\N
execution:delete	execution:delete	\N
execution:read	execution:read	\N
execution:retry	execution:retry	\N
execution:list	execution:list	\N
execution:get	execution:get	\N
execution:reveal	execution:reveal	\N
execution:*	execution:*	\N
workflowTags:update	workflowTags:update	\N
workflowTags:list	workflowTags:list	\N
workflowTags:*	workflowTags:*	\N
role:manage	role:manage	\N
role:*	role:*	\N
mcp:manage	mcp:manage	\N
mcp:oauth	mcp:oauth	\N
mcp:*	mcp:*	\N
mcpApiKey:create	mcpApiKey:create	\N
mcpApiKey:rotate	mcpApiKey:rotate	\N
mcpApiKey:*	mcpApiKey:*	\N
chatHub:manage	chatHub:manage	\N
chatHub:message	chatHub:message	\N
chatHub:*	chatHub:*	\N
chatHubAgent:create	chatHubAgent:create	\N
chatHubAgent:read	chatHubAgent:read	\N
chatHubAgent:update	chatHubAgent:update	\N
chatHubAgent:delete	chatHubAgent:delete	\N
chatHubAgent:list	chatHubAgent:list	\N
chatHubAgent:*	chatHubAgent:*	\N
breakingChanges:list	breakingChanges:list	\N
breakingChanges:*	breakingChanges:*	\N
apiKey:manage	apiKey:manage	\N
apiKey:*	apiKey:*	\N
credentialResolver:create	credentialResolver:create	\N
credentialResolver:read	credentialResolver:read	\N
credentialResolver:update	credentialResolver:update	\N
credentialResolver:delete	credentialResolver:delete	\N
credentialResolver:list	credentialResolver:list	\N
credentialResolver:*	credentialResolver:*	\N
*	*	\N
workflow:publish	Publish Workflow	Allows publishing workflows.
\.


--
-- Data for Name: secrets_provider_connection; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.secrets_provider_connection (id, "providerKey", type, "encryptedSettings", "isEnabled", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: settings; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.settings (key, value, "loadOnStartup") FROM stdin;
userManagement.isInstanceOwnerSetUp	false	t
ui.banners.dismissed	["V1"]	t
features.ldap	{"loginEnabled":false,"loginLabel":"","connectionUrl":"","allowUnauthorizedCerts":false,"connectionSecurity":"none","connectionPort":389,"baseDn":"","bindingAdminDn":"","bindingAdminPassword":"","firstNameAttribute":"","lastNameAttribute":"","emailAttribute":"","loginIdAttribute":"","ldapIdAttribute":"","userFilter":"","synchronizationEnabled":false,"synchronizationInterval":60,"searchPageSize":0,"searchTimeout":60,"enforceEmailUniqueness":true}	t
\.


--
-- Data for Name: shared_credentials; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.shared_credentials ("credentialsId", "projectId", role, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: shared_workflow; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.shared_workflow ("workflowId", "projectId", role, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: tag_entity; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.tag_entity (name, "createdAt", "updatedAt", id) FROM stdin;
\.


--
-- Data for Name: test_case_execution; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.test_case_execution (id, "testRunId", "executionId", status, "runAt", "completedAt", "errorCode", "errorDetails", metrics, "createdAt", "updatedAt", inputs, outputs) FROM stdin;
\.


--
-- Data for Name: test_run; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.test_run (id, "workflowId", status, "errorCode", "errorDetails", "runAt", "completedAt", metrics, "createdAt", "updatedAt", "runningInstanceId", "cancelRequested") FROM stdin;
\.


--
-- Data for Name: tipos_masa; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.tipos_masa (tipo_masa, peso_masa_g, descripcion, activo, fecha_creacion) FROM stdin;
BASICA_LM	2184	Masa Básica Larga Maduración	t	2026-06-30 23:36:02.265836
FRANCESA	2195	Masa Francesa	t	2026-04-27 22:59:19.81884
ESTANDAR	2065	Masa Estándar	t	2026-04-29 18:12:32.582966
SOBADA	2039	Masa Sobada para Hamburguesa	t	2026-04-29 18:12:32.582966
SOBADA_PE	2023	Masa Sobada para Perro Caliente	t	2026-06-30 23:36:02.265836
PAPA	2096	Masa de Papa	t	2026-04-29 18:12:32.582966
PAPA_LM	2113	Masa de Papa Larga Maduración	t	2026-06-30 23:36:02.265836
BATATA_LM	2308	Masa de Batata Larga Maduración	t	2026-06-30 23:36:02.265836
MANTEQUILLA	2073	Masa de Mantequilla	t	2026-04-29 18:12:32.582966
MANTEQUILLA_LM	2089	Masa de Mantequilla Larga Maduración	t	2026-06-30 23:36:02.265836
BRIOCHE_LM	2100	Masa Brioche Larga Maduración	t	2026-06-30 23:37:55.35342
HOJALDRADA	2145	Masa Hojaldrada	t	2026-04-29 18:12:32.582966
CROISSANTS_SEMI	2343	Masa Croissant Semi	t	2026-06-30 23:37:55.35342
AFRECHO_MANT_MIEL	2490	Masa Afrecho Mantequilla y Miel	t	2026-06-30 23:37:55.35342
PREMIUM	640	Sandwich premium	f	2026-04-29 18:12:32.582966
INTEGRAL	640	Pan integral	f	2026-04-29 18:12:32.582966
ABRIOCHADA	1792	Masa Abriochada	t	2026-04-29 18:12:32.582966
SOBADA_PA	2173	Masa Sobada para Pan / Panini	t	2026-06-30 23:36:02.265836
CROISSANTS	2407	Masa Croissant	t	2026-06-30 23:37:55.35342
BATATA	2264	Masa de Batata	t	2026-04-29 18:12:32.582966
BRIOCHE	1880	Masa Brioche	t	2026-04-29 18:12:32.582966
BASICA	1862	Masa Básica	t	2026-04-27 22:59:19.902578
\.


--
-- Data for Name: topings; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.topings (id_toping, nombre, activo) FROM stdin;
1	Ajonjoli	t
2	Queso	t
3	Oregano	t
4	Mantequilla	t
5	Sin toping	t
\.


--
-- Data for Name: user; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public."user" (id, email, "firstName", "lastName", password, "personalizationAnswers", "createdAt", "updatedAt", settings, disabled, "mfaEnabled", "mfaSecret", "mfaRecoveryCodes", "lastActiveAt", "roleSlug") FROM stdin;
6e0e5e92-e7d5-45a6-9ba3-de8c62bf1b5f	\N	\N	\N	\N	\N	2026-04-26 16:04:10.032+00	2026-04-26 16:04:10.032+00	{"userActivated": false}	f	f	\N	\N	\N	global:owner
\.


--
-- Data for Name: user_api_keys; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.user_api_keys (id, "userId", label, "apiKey", "createdAt", "updatedAt", scopes, audience) FROM stdin;
\.


--
-- Data for Name: usuarios; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.usuarios (id_usuario, telegram_id, nombre, rol, estado, fecha_registro, ultimo_acceso) FROM stdin;
1	@luisepm92	Luis (Dueno)	DUENO	activo	2026-04-26 16:03:54.351116	\N
\.


--
-- Data for Name: usuarios_dashboard; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.usuarios_dashboard (id, usuario, "contraseña", nombre, fecha_creacion) FROM stdin;
1	admin	admin123	Administrador	2026-04-28 14:46:45.249366
\.


--
-- Data for Name: variables; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.variables (key, type, value, id, "projectId") FROM stdin;
\.


--
-- Data for Name: webhook_entity; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.webhook_entity ("webhookPath", method, node, "webhookId", "pathLength", "workflowId") FROM stdin;
\.


--
-- Data for Name: workflow_builder_session; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.workflow_builder_session (id, "workflowId", "userId", messages, "previousSummary", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: workflow_dependency; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.workflow_dependency (id, "workflowId", "workflowVersionId", "dependencyType", "dependencyKey", "dependencyInfo", "indexVersionId", "createdAt", "publishedVersionId") FROM stdin;
\.


--
-- Data for Name: workflow_entity; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.workflow_entity (name, active, nodes, connections, "createdAt", "updatedAt", settings, "staticData", "pinData", "versionId", "triggerCount", id, meta, "parentFolderId", "isArchived", "versionCounter", description, "activeVersionId") FROM stdin;
\.


--
-- Data for Name: workflow_history; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.workflow_history ("versionId", "workflowId", authors, "createdAt", "updatedAt", nodes, connections, name, autosaved, description) FROM stdin;
\.


--
-- Data for Name: workflow_publish_history; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.workflow_publish_history (id, "workflowId", "versionId", event, "userId", "createdAt") FROM stdin;
\.


--
-- Data for Name: workflow_published_version; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.workflow_published_version ("workflowId", "publishedVersionId", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: workflow_statistics; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.workflow_statistics (count, "latestEvent", name, "workflowId", "rootCount", id, "workflowName") FROM stdin;
\.


--
-- Data for Name: workflows_tags; Type: TABLE DATA; Schema: public; Owner: panif_user
--

COPY public.workflows_tags ("workflowId", "tagId") FROM stdin;
\.


--
-- Name: auth_provider_sync_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: panif_user
--

SELECT pg_catalog.setval('public.auth_provider_sync_history_id_seq', 1, false);


--
-- Name: clientes_id_cliente_seq; Type: SEQUENCE SET; Schema: public; Owner: panif_user
--

SELECT pg_catalog.setval('public.clientes_id_cliente_seq', 76, true);


--
-- Name: detalle_pedidos_id_detalle_seq; Type: SEQUENCE SET; Schema: public; Owner: panif_user
--

SELECT pg_catalog.setval('public.detalle_pedidos_id_detalle_seq', 66, true);


--
-- Name: deudas_id_deuda_seq; Type: SEQUENCE SET; Schema: public; Owner: panif_user
--

SELECT pg_catalog.setval('public.deudas_id_deuda_seq', 58, true);


--
-- Name: execution_annotations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: panif_user
--

SELECT pg_catalog.setval('public.execution_annotations_id_seq', 1, false);


--
-- Name: execution_entity_id_seq; Type: SEQUENCE SET; Schema: public; Owner: panif_user
--

SELECT pg_catalog.setval('public.execution_entity_id_seq', 1, false);


--
-- Name: execution_metadata_temp_id_seq; Type: SEQUENCE SET; Schema: public; Owner: panif_user
--

SELECT pg_catalog.setval('public.execution_metadata_temp_id_seq', 1, false);


--
-- Name: insights_by_period_id_seq; Type: SEQUENCE SET; Schema: public; Owner: panif_user
--

SELECT pg_catalog.setval('public.insights_by_period_id_seq', 1, false);


--
-- Name: insights_metadata_metaId_seq; Type: SEQUENCE SET; Schema: public; Owner: panif_user
--

SELECT pg_catalog.setval('public."insights_metadata_metaId_seq"', 1, false);


--
-- Name: insights_raw_id_seq; Type: SEQUENCE SET; Schema: public; Owner: panif_user
--

SELECT pg_catalog.setval('public.insights_raw_id_seq', 1, false);


--
-- Name: migrations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: panif_user
--

SELECT pg_catalog.setval('public.migrations_id_seq', 152, true);


--
-- Name: oauth_user_consents_id_seq; Type: SEQUENCE SET; Schema: public; Owner: panif_user
--

SELECT pg_catalog.setval('public.oauth_user_consents_id_seq', 1, false);


--
-- Name: pagos_id_pago_seq; Type: SEQUENCE SET; Schema: public; Owner: panif_user
--

SELECT pg_catalog.setval('public.pagos_id_pago_seq', 3, true);


--
-- Name: pedidos_id_pedido_seq; Type: SEQUENCE SET; Schema: public; Owner: panif_user
--

SELECT pg_catalog.setval('public.pedidos_id_pedido_seq', 59, true);


--
-- Name: produccion_diaria_id_produccion_seq; Type: SEQUENCE SET; Schema: public; Owner: panif_user
--

SELECT pg_catalog.setval('public.produccion_diaria_id_produccion_seq', 72, true);


--
-- Name: productos_id_producto_seq; Type: SEQUENCE SET; Schema: public; Owner: panif_user
--

SELECT pg_catalog.setval('public.productos_id_producto_seq', 140, true);


--
-- Name: recetas_masa_id_receta_seq; Type: SEQUENCE SET; Schema: public; Owner: panif_user
--

SELECT pg_catalog.setval('public.recetas_masa_id_receta_seq', 268, true);


--
-- Name: secrets_provider_connection_id_seq; Type: SEQUENCE SET; Schema: public; Owner: panif_user
--

SELECT pg_catalog.setval('public.secrets_provider_connection_id_seq', 1, false);


--
-- Name: topings_id_toping_seq; Type: SEQUENCE SET; Schema: public; Owner: panif_user
--

SELECT pg_catalog.setval('public.topings_id_toping_seq', 5, true);


--
-- Name: usuarios_dashboard_id_seq; Type: SEQUENCE SET; Schema: public; Owner: panif_user
--

SELECT pg_catalog.setval('public.usuarios_dashboard_id_seq', 1, true);


--
-- Name: usuarios_id_usuario_seq; Type: SEQUENCE SET; Schema: public; Owner: panif_user
--

SELECT pg_catalog.setval('public.usuarios_id_usuario_seq', 2, true);


--
-- Name: workflow_dependency_id_seq; Type: SEQUENCE SET; Schema: public; Owner: panif_user
--

SELECT pg_catalog.setval('public.workflow_dependency_id_seq', 1, false);


--
-- Name: workflow_publish_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: panif_user
--

SELECT pg_catalog.setval('public.workflow_publish_history_id_seq', 1, false);


--
-- Name: workflow_statistics_id_seq; Type: SEQUENCE SET; Schema: public; Owner: panif_user
--

SELECT pg_catalog.setval('public.workflow_statistics_id_seq', 1, false);


--
-- Name: test_run PK_011c050f566e9db509a0fadb9b9; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.test_run
    ADD CONSTRAINT "PK_011c050f566e9db509a0fadb9b9" PRIMARY KEY (id);


--
-- Name: project_secrets_provider_access PK_0402b7fcec5415246656f102f83; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.project_secrets_provider_access
    ADD CONSTRAINT "PK_0402b7fcec5415246656f102f83" PRIMARY KEY ("secretsProviderConnectionId", "projectId");


--
-- Name: installed_packages PK_08cc9197c39b028c1e9beca225940576fd1a5804; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.installed_packages
    ADD CONSTRAINT "PK_08cc9197c39b028c1e9beca225940576fd1a5804" PRIMARY KEY ("packageName");


--
-- Name: execution_metadata PK_17a0b6284f8d626aae88e1c16e4; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.execution_metadata
    ADD CONSTRAINT "PK_17a0b6284f8d626aae88e1c16e4" PRIMARY KEY (id);


--
-- Name: project_relation PK_1caaa312a5d7184a003be0f0cb6; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.project_relation
    ADD CONSTRAINT "PK_1caaa312a5d7184a003be0f0cb6" PRIMARY KEY ("projectId", "userId");


--
-- Name: chat_hub_sessions PK_1eafef1273c70e4464fec703412; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.chat_hub_sessions
    ADD CONSTRAINT "PK_1eafef1273c70e4464fec703412" PRIMARY KEY (id);


--
-- Name: folder_tag PK_27e4e00852f6b06a925a4d83a3e; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.folder_tag
    ADD CONSTRAINT "PK_27e4e00852f6b06a925a4d83a3e" PRIMARY KEY ("folderId", "tagId");


--
-- Name: role PK_35c9b140caaf6da09cfabb0d675; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.role
    ADD CONSTRAINT "PK_35c9b140caaf6da09cfabb0d675" PRIMARY KEY (slug);


--
-- Name: secrets_provider_connection PK_4350ae85e76f9ba7df1370acb5d; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.secrets_provider_connection
    ADD CONSTRAINT "PK_4350ae85e76f9ba7df1370acb5d" PRIMARY KEY (id);


--
-- Name: project PK_4d68b1358bb5b766d3e78f32f57; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.project
    ADD CONSTRAINT "PK_4d68b1358bb5b766d3e78f32f57" PRIMARY KEY (id);


--
-- Name: dynamic_credential_entry PK_5135ffcabecad4727ff6b9b803d; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.dynamic_credential_entry
    ADD CONSTRAINT "PK_5135ffcabecad4727ff6b9b803d" PRIMARY KEY (credential_id, subject_id, resolver_id);


--
-- Name: workflow_dependency PK_52325e34cd7a2f0f67b0f3cad65; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.workflow_dependency
    ADD CONSTRAINT "PK_52325e34cd7a2f0f67b0f3cad65" PRIMARY KEY (id);


--
-- Name: invalid_auth_token PK_5779069b7235b256d91f7af1a15; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.invalid_auth_token
    ADD CONSTRAINT "PK_5779069b7235b256d91f7af1a15" PRIMARY KEY (token);


--
-- Name: shared_workflow PK_5ba87620386b847201c9531c58f; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.shared_workflow
    ADD CONSTRAINT "PK_5ba87620386b847201c9531c58f" PRIMARY KEY ("workflowId", "projectId");


--
-- Name: workflow_published_version PK_5c76fb7ee939fe2530374d3f75a; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.workflow_published_version
    ADD CONSTRAINT "PK_5c76fb7ee939fe2530374d3f75a" PRIMARY KEY ("workflowId");


--
-- Name: folder PK_6278a41a706740c94c02e288df8; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.folder
    ADD CONSTRAINT "PK_6278a41a706740c94c02e288df8" PRIMARY KEY (id);


--
-- Name: data_table_column PK_673cb121ee4a8a5e27850c72c51; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.data_table_column
    ADD CONSTRAINT "PK_673cb121ee4a8a5e27850c72c51" PRIMARY KEY (id);


--
-- Name: chat_hub_tools PK_696d26426c704fba79b2c195ef5; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.chat_hub_tools
    ADD CONSTRAINT "PK_696d26426c704fba79b2c195ef5" PRIMARY KEY (id);


--
-- Name: annotation_tag_entity PK_69dfa041592c30bbc0d4b84aa00; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.annotation_tag_entity
    ADD CONSTRAINT "PK_69dfa041592c30bbc0d4b84aa00" PRIMARY KEY (id);


--
-- Name: oauth_refresh_tokens PK_74abaed0b30711b6532598b0392; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.oauth_refresh_tokens
    ADD CONSTRAINT "PK_74abaed0b30711b6532598b0392" PRIMARY KEY (token);


--
-- Name: dynamic_credential_user_entry PK_74f548e633abc66dc27c8f0ca77; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.dynamic_credential_user_entry
    ADD CONSTRAINT "PK_74f548e633abc66dc27c8f0ca77" PRIMARY KEY ("credentialId", "userId", "resolverId");


--
-- Name: chat_hub_messages PK_7704a5add6baed43eef835f0bfb; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "PK_7704a5add6baed43eef835f0bfb" PRIMARY KEY (id);


--
-- Name: execution_annotations PK_7afcf93ffa20c4252869a7c6a23; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.execution_annotations
    ADD CONSTRAINT "PK_7afcf93ffa20c4252869a7c6a23" PRIMARY KEY (id);


--
-- Name: oauth_user_consents PK_85b9ada746802c8993103470f05; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.oauth_user_consents
    ADD CONSTRAINT "PK_85b9ada746802c8993103470f05" PRIMARY KEY (id);


--
-- Name: chat_hub_session_tools PK_87aea76ff4c274c4a5ac838ebe3; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.chat_hub_session_tools
    ADD CONSTRAINT "PK_87aea76ff4c274c4a5ac838ebe3" PRIMARY KEY ("sessionId", "toolId");


--
-- Name: migrations PK_8c82d7f526340ab734260ea46be; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.migrations
    ADD CONSTRAINT "PK_8c82d7f526340ab734260ea46be" PRIMARY KEY (id);


--
-- Name: installed_nodes PK_8ebd28194e4f792f96b5933423fc439df97d9689; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.installed_nodes
    ADD CONSTRAINT "PK_8ebd28194e4f792f96b5933423fc439df97d9689" PRIMARY KEY (name);


--
-- Name: shared_credentials PK_8ef3a59796a228913f251779cff; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.shared_credentials
    ADD CONSTRAINT "PK_8ef3a59796a228913f251779cff" PRIMARY KEY ("credentialsId", "projectId");


--
-- Name: test_case_execution PK_90c121f77a78a6580e94b794bce; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.test_case_execution
    ADD CONSTRAINT "PK_90c121f77a78a6580e94b794bce" PRIMARY KEY (id);


--
-- Name: user_api_keys PK_978fa5caa3468f463dac9d92e69; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.user_api_keys
    ADD CONSTRAINT "PK_978fa5caa3468f463dac9d92e69" PRIMARY KEY (id);


--
-- Name: execution_annotation_tags PK_979ec03d31294cca484be65d11f; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.execution_annotation_tags
    ADD CONSTRAINT "PK_979ec03d31294cca484be65d11f" PRIMARY KEY ("annotationId", "tagId");


--
-- Name: webhook_entity PK_b21ace2e13596ccd87dc9bf4ea6; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.webhook_entity
    ADD CONSTRAINT "PK_b21ace2e13596ccd87dc9bf4ea6" PRIMARY KEY ("webhookPath", method);


--
-- Name: insights_by_period PK_b606942249b90cc39b0265f0575; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.insights_by_period
    ADD CONSTRAINT "PK_b606942249b90cc39b0265f0575" PRIMARY KEY (id);


--
-- Name: workflow_history PK_b6572dd6173e4cd06fe79937b58; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.workflow_history
    ADD CONSTRAINT "PK_b6572dd6173e4cd06fe79937b58" PRIMARY KEY ("versionId");


--
-- Name: dynamic_credential_resolver PK_b76cfb088dcdaf5275e9980bb64; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.dynamic_credential_resolver
    ADD CONSTRAINT "PK_b76cfb088dcdaf5275e9980bb64" PRIMARY KEY (id);


--
-- Name: scope PK_bfc45df0481abd7f355d6187da1; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.scope
    ADD CONSTRAINT "PK_bfc45df0481abd7f355d6187da1" PRIMARY KEY (slug);


--
-- Name: oauth_clients PK_c4759172d3431bae6f04e678e0d; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.oauth_clients
    ADD CONSTRAINT "PK_c4759172d3431bae6f04e678e0d" PRIMARY KEY (id);


--
-- Name: workflow_publish_history PK_c788f7caf88e91e365c97d6d04a; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.workflow_publish_history
    ADD CONSTRAINT "PK_c788f7caf88e91e365c97d6d04a" PRIMARY KEY (id);


--
-- Name: processed_data PK_ca04b9d8dc72de268fe07a65773; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.processed_data
    ADD CONSTRAINT "PK_ca04b9d8dc72de268fe07a65773" PRIMARY KEY ("workflowId", context);


--
-- Name: chat_hub_agent_tools PK_cc8806fdea48297a7d497035d72; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.chat_hub_agent_tools
    ADD CONSTRAINT "PK_cc8806fdea48297a7d497035d72" PRIMARY KEY ("agentId", "toolId");


--
-- Name: settings PK_dc0fe14e6d9943f268e7b119f69ab8bd; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.settings
    ADD CONSTRAINT "PK_dc0fe14e6d9943f268e7b119f69ab8bd" PRIMARY KEY (key);


--
-- Name: oauth_access_tokens PK_dcd71f96a5d5f4bf79e67d322bf; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.oauth_access_tokens
    ADD CONSTRAINT "PK_dcd71f96a5d5f4bf79e67d322bf" PRIMARY KEY (token);


--
-- Name: data_table PK_e226d0001b9e6097cbfe70617cb; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.data_table
    ADD CONSTRAINT "PK_e226d0001b9e6097cbfe70617cb" PRIMARY KEY (id);


--
-- Name: workflow_builder_session PK_e69ef0d385986e273423b0e8695; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.workflow_builder_session
    ADD CONSTRAINT "PK_e69ef0d385986e273423b0e8695" PRIMARY KEY (id);


--
-- Name: user PK_ea8f538c94b6e352418254ed6474a81f; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT "PK_ea8f538c94b6e352418254ed6474a81f" PRIMARY KEY (id);


--
-- Name: insights_raw PK_ec15125755151e3a7e00e00014f; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.insights_raw
    ADD CONSTRAINT "PK_ec15125755151e3a7e00e00014f" PRIMARY KEY (id);


--
-- Name: chat_hub_agents PK_f39a3b36bbdf0e2979ddb21cf78; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.chat_hub_agents
    ADD CONSTRAINT "PK_f39a3b36bbdf0e2979ddb21cf78" PRIMARY KEY (id);


--
-- Name: insights_metadata PK_f448a94c35218b6208ce20cf5a1; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.insights_metadata
    ADD CONSTRAINT "PK_f448a94c35218b6208ce20cf5a1" PRIMARY KEY ("metaId");


--
-- Name: oauth_authorization_codes PK_fb91ab932cfbd694061501cc20f; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.oauth_authorization_codes
    ADD CONSTRAINT "PK_fb91ab932cfbd694061501cc20f" PRIMARY KEY (code);


--
-- Name: binary_data PK_fc3691585b39408bb0551122af6; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.binary_data
    ADD CONSTRAINT "PK_fc3691585b39408bb0551122af6" PRIMARY KEY ("fileId");


--
-- Name: role_scope PK_role_scope; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.role_scope
    ADD CONSTRAINT "PK_role_scope" PRIMARY KEY ("roleSlug", "scopeSlug");


--
-- Name: oauth_user_consents UQ_083721d99ce8db4033e2958ebb4; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.oauth_user_consents
    ADD CONSTRAINT "UQ_083721d99ce8db4033e2958ebb4" UNIQUE ("userId", "clientId");


--
-- Name: data_table_column UQ_8082ec4890f892f0bc77473a123; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.data_table_column
    ADD CONSTRAINT "UQ_8082ec4890f892f0bc77473a123" UNIQUE ("dataTableId", name);


--
-- Name: data_table UQ_b23096ef747281ac944d28e8b0d; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.data_table
    ADD CONSTRAINT "UQ_b23096ef747281ac944d28e8b0d" UNIQUE ("projectId", name);


--
-- Name: user UQ_e12875dfb3b1d92d7d7c5377e2; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT "UQ_e12875dfb3b1d92d7d7c5377e2" UNIQUE (email);


--
-- Name: workflow_builder_session UQ_ec2aa73632932d485a1d5192ce1; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.workflow_builder_session
    ADD CONSTRAINT "UQ_ec2aa73632932d485a1d5192ce1" UNIQUE ("workflowId", "userId");


--
-- Name: auth_identity auth_identity_pkey; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.auth_identity
    ADD CONSTRAINT auth_identity_pkey PRIMARY KEY ("providerId", "providerType");


--
-- Name: auth_provider_sync_history auth_provider_sync_history_pkey; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.auth_provider_sync_history
    ADD CONSTRAINT auth_provider_sync_history_pkey PRIMARY KEY (id);


--
-- Name: clientes clientes_pkey; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.clientes
    ADD CONSTRAINT clientes_pkey PRIMARY KEY (id_cliente);


--
-- Name: clientes clientes_telegram_id_key; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.clientes
    ADD CONSTRAINT clientes_telegram_id_key UNIQUE (telegram_id);


--
-- Name: credentials_entity credentials_entity_pkey; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.credentials_entity
    ADD CONSTRAINT credentials_entity_pkey PRIMARY KEY (id);


--
-- Name: detalle_pedidos detalle_pedidos_pkey; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.detalle_pedidos
    ADD CONSTRAINT detalle_pedidos_pkey PRIMARY KEY (id_detalle);


--
-- Name: deudas deudas_pkey; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.deudas
    ADD CONSTRAINT deudas_pkey PRIMARY KEY (id_deuda);


--
-- Name: event_destinations event_destinations_pkey; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.event_destinations
    ADD CONSTRAINT event_destinations_pkey PRIMARY KEY (id);


--
-- Name: execution_data execution_data_pkey; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.execution_data
    ADD CONSTRAINT execution_data_pkey PRIMARY KEY ("executionId");


--
-- Name: pagos pagos_pkey; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT pagos_pkey PRIMARY KEY (id_pago);


--
-- Name: pedidos pedidos_numero_recibo_key; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.pedidos
    ADD CONSTRAINT pedidos_numero_recibo_key UNIQUE (numero_recibo);


--
-- Name: pedidos pedidos_pkey; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.pedidos
    ADD CONSTRAINT pedidos_pkey PRIMARY KEY (id_pedido);


--
-- Name: execution_entity pk_e3e63bbf986767844bbe1166d4e; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.execution_entity
    ADD CONSTRAINT pk_e3e63bbf986767844bbe1166d4e PRIMARY KEY (id);


--
-- Name: workflows_tags pk_workflows_tags; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.workflows_tags
    ADD CONSTRAINT pk_workflows_tags PRIMARY KEY ("workflowId", "tagId");


--
-- Name: produccion_diaria produccion_diaria_fecha_tipo_pan_producto_peso_key; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.produccion_diaria
    ADD CONSTRAINT produccion_diaria_fecha_tipo_pan_producto_peso_key UNIQUE NULLS NOT DISTINCT (fecha_produccion, tipo_pan, producto, peso_g);


--
-- Name: produccion_diaria produccion_diaria_pkey; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.produccion_diaria
    ADD CONSTRAINT produccion_diaria_pkey PRIMARY KEY (id_produccion);


--
-- Name: productos productos_nombre_key; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.productos
    ADD CONSTRAINT productos_nombre_key UNIQUE (nombre);


--
-- Name: productos productos_pkey; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.productos
    ADD CONSTRAINT productos_pkey PRIMARY KEY (id_producto);


--
-- Name: recetas_masa recetas_masa_pkey; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.recetas_masa
    ADD CONSTRAINT recetas_masa_pkey PRIMARY KEY (id_receta);


--
-- Name: recetas_masa recetas_masa_tipo_masa_ingrediente_key; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.recetas_masa
    ADD CONSTRAINT recetas_masa_tipo_masa_ingrediente_key UNIQUE (tipo_masa, ingrediente);


--
-- Name: tag_entity tag_entity_pkey; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.tag_entity
    ADD CONSTRAINT tag_entity_pkey PRIMARY KEY (id);


--
-- Name: tipos_masa tipos_masa_pkey; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.tipos_masa
    ADD CONSTRAINT tipos_masa_pkey PRIMARY KEY (tipo_masa);


--
-- Name: topings topings_nombre_key; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.topings
    ADD CONSTRAINT topings_nombre_key UNIQUE (nombre);


--
-- Name: topings topings_pkey; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.topings
    ADD CONSTRAINT topings_pkey PRIMARY KEY (id_toping);


--
-- Name: usuarios_dashboard usuarios_dashboard_pkey; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.usuarios_dashboard
    ADD CONSTRAINT usuarios_dashboard_pkey PRIMARY KEY (id);


--
-- Name: usuarios_dashboard usuarios_dashboard_usuario_key; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.usuarios_dashboard
    ADD CONSTRAINT usuarios_dashboard_usuario_key UNIQUE (usuario);


--
-- Name: usuarios usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id_usuario);


--
-- Name: usuarios usuarios_telegram_id_key; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_telegram_id_key UNIQUE (telegram_id);


--
-- Name: variables variables_pkey; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.variables
    ADD CONSTRAINT variables_pkey PRIMARY KEY (id);


--
-- Name: workflow_entity workflow_entity_pkey; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.workflow_entity
    ADD CONSTRAINT workflow_entity_pkey PRIMARY KEY (id);


--
-- Name: workflow_statistics workflow_statistics_pkey; Type: CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.workflow_statistics
    ADD CONSTRAINT workflow_statistics_pkey PRIMARY KEY (id);


--
-- Name: IDX_070b5de842ece9ccdda0d9738b; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX "IDX_070b5de842ece9ccdda0d9738b" ON public.workflow_publish_history USING btree ("workflowId", "versionId");


--
-- Name: IDX_14f68deffaf858465715995508; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE UNIQUE INDEX "IDX_14f68deffaf858465715995508" ON public.folder USING btree ("projectId", id);


--
-- Name: IDX_1d8ab99d5861c9388d2dc1cf73; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE UNIQUE INDEX "IDX_1d8ab99d5861c9388d2dc1cf73" ON public.insights_metadata USING btree ("workflowId");


--
-- Name: IDX_1e31657f5fe46816c34be7c1b4; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX "IDX_1e31657f5fe46816c34be7c1b4" ON public.workflow_history USING btree ("workflowId");


--
-- Name: IDX_1ef35bac35d20bdae979d917a3; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE UNIQUE INDEX "IDX_1ef35bac35d20bdae979d917a3" ON public.user_api_keys USING btree ("apiKey");


--
-- Name: IDX_4c72ebdb265d1775bf61147af0; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE UNIQUE INDEX "IDX_4c72ebdb265d1775bf61147af0" ON public.chat_hub_tools USING btree ("ownerId", name);


--
-- Name: IDX_56900edc3cfd16612e2ef2c6a8; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX "IDX_56900edc3cfd16612e2ef2c6a8" ON public.binary_data USING btree ("sourceType", "sourceId");


--
-- Name: IDX_5f0643f6717905a05164090dde; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX "IDX_5f0643f6717905a05164090dde" ON public.project_relation USING btree ("userId");


--
-- Name: IDX_60b6a84299eeb3f671dfec7693; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE UNIQUE INDEX "IDX_60b6a84299eeb3f671dfec7693" ON public.insights_by_period USING btree ("periodStart", type, "periodUnit", "metaId");


--
-- Name: IDX_61448d56d61802b5dfde5cdb00; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX "IDX_61448d56d61802b5dfde5cdb00" ON public.project_relation USING btree ("projectId");


--
-- Name: IDX_62476b94b56d9dc7ed9ed75d3d; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX "IDX_62476b94b56d9dc7ed9ed75d3d" ON public.dynamic_credential_entry USING btree (subject_id);


--
-- Name: IDX_63d7bbae72c767cf162d459fcc; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE UNIQUE INDEX "IDX_63d7bbae72c767cf162d459fcc" ON public.user_api_keys USING btree ("userId", label);


--
-- Name: IDX_6edec973a6450990977bb854c3; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX "IDX_6edec973a6450990977bb854c3" ON public.dynamic_credential_user_entry USING btree ("resolverId");


--
-- Name: IDX_8e4b4774db42f1e6dda3452b2a; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX "IDX_8e4b4774db42f1e6dda3452b2a" ON public.test_case_execution USING btree ("testRunId");


--
-- Name: IDX_97f863fa83c4786f1956508496; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE UNIQUE INDEX "IDX_97f863fa83c4786f1956508496" ON public.execution_annotations USING btree ("executionId");


--
-- Name: IDX_9c9ee9df586e60bb723234e499; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX "IDX_9c9ee9df586e60bb723234e499" ON public.dynamic_credential_resolver USING btree (type);


--
-- Name: IDX_UniqueRoleDisplayName; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE UNIQUE INDEX "IDX_UniqueRoleDisplayName" ON public.role USING btree ("displayName");


--
-- Name: IDX_a3697779b366e131b2bbdae297; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX "IDX_a3697779b366e131b2bbdae297" ON public.execution_annotation_tags USING btree ("tagId");


--
-- Name: IDX_a36dc616fabc3f736bb82410a2; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX "IDX_a36dc616fabc3f736bb82410a2" ON public.dynamic_credential_user_entry USING btree ("userId");


--
-- Name: IDX_a4ff2d9b9628ea988fa9e7d0bf; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX "IDX_a4ff2d9b9628ea988fa9e7d0bf" ON public.workflow_dependency USING btree ("workflowId");


--
-- Name: IDX_ae51b54c4bb430cf92f48b623f; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE UNIQUE INDEX "IDX_ae51b54c4bb430cf92f48b623f" ON public.annotation_tag_entity USING btree (name);


--
-- Name: IDX_c1519757391996eb06064f0e7c; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX "IDX_c1519757391996eb06064f0e7c" ON public.execution_annotation_tags USING btree ("annotationId");


--
-- Name: IDX_cec8eea3bf49551482ccb4933e; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE UNIQUE INDEX "IDX_cec8eea3bf49551482ccb4933e" ON public.execution_metadata USING btree ("executionId", key);


--
-- Name: IDX_chat_hub_messages_sessionId; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX "IDX_chat_hub_messages_sessionId" ON public.chat_hub_messages USING btree ("sessionId");


--
-- Name: IDX_chat_hub_sessions_owner_lastmsg_id; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX "IDX_chat_hub_sessions_owner_lastmsg_id" ON public.chat_hub_sessions USING btree ("ownerId", "lastMessageAt" DESC, id);


--
-- Name: IDX_d61a12235d268a49af6a3c09c1; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX "IDX_d61a12235d268a49af6a3c09c1" ON public.dynamic_credential_entry USING btree (resolver_id);


--
-- Name: IDX_d6870d3b6e4c185d33926f423c; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX "IDX_d6870d3b6e4c185d33926f423c" ON public.test_run USING btree ("workflowId");


--
-- Name: IDX_e48a201071ab85d9d09119d640; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX "IDX_e48a201071ab85d9d09119d640" ON public.workflow_dependency USING btree ("dependencyKey");


--
-- Name: IDX_e7fe1cfda990c14a445937d0b9; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX "IDX_e7fe1cfda990c14a445937d0b9" ON public.workflow_dependency USING btree ("dependencyType");


--
-- Name: IDX_execution_entity_deletedAt; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX "IDX_execution_entity_deletedAt" ON public.execution_entity USING btree ("deletedAt");


--
-- Name: IDX_role_scope_scopeSlug; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX "IDX_role_scope_scopeSlug" ON public.role_scope USING btree ("scopeSlug");


--
-- Name: IDX_secrets_provider_connection_providerKey; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE UNIQUE INDEX "IDX_secrets_provider_connection_providerKey" ON public.secrets_provider_connection USING btree ("providerKey");


--
-- Name: IDX_workflow_dependency_publishedVersionId; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX "IDX_workflow_dependency_publishedVersionId" ON public.workflow_dependency USING btree ("publishedVersionId");


--
-- Name: IDX_workflow_entity_name; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX "IDX_workflow_entity_name" ON public.workflow_entity USING btree (name);


--
-- Name: IDX_workflow_statistics_workflow_name; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE UNIQUE INDEX "IDX_workflow_statistics_workflow_name" ON public.workflow_statistics USING btree ("workflowId", name);


--
-- Name: idx_07fde106c0b471d8cc80a64fc8; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX idx_07fde106c0b471d8cc80a64fc8 ON public.credentials_entity USING btree (type);


--
-- Name: idx_16f4436789e804e3e1c9eeb240; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX idx_16f4436789e804e3e1c9eeb240 ON public.webhook_entity USING btree ("webhookId", method, "pathLength");


--
-- Name: idx_812eb05f7451ca757fb98444ce; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE UNIQUE INDEX idx_812eb05f7451ca757fb98444ce ON public.tag_entity USING btree (name);


--
-- Name: idx_clientes_estado; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX idx_clientes_estado ON public.clientes USING btree (estado);


--
-- Name: idx_clientes_nombre; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX idx_clientes_nombre ON public.clientes USING btree (nombre_negocio);


--
-- Name: idx_detalle_pedido; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX idx_detalle_pedido ON public.detalle_pedidos USING btree (id_pedido);


--
-- Name: idx_deudas_cliente; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX idx_deudas_cliente ON public.deudas USING btree (id_cliente);


--
-- Name: idx_deudas_estado; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX idx_deudas_estado ON public.deudas USING btree (estado);


--
-- Name: idx_execution_entity_stopped_at_status_deleted_at; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX idx_execution_entity_stopped_at_status_deleted_at ON public.execution_entity USING btree ("stoppedAt", status, "deletedAt") WHERE (("stoppedAt" IS NOT NULL) AND ("deletedAt" IS NULL));


--
-- Name: idx_execution_entity_wait_till_status_deleted_at; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX idx_execution_entity_wait_till_status_deleted_at ON public.execution_entity USING btree ("waitTill", status, "deletedAt") WHERE (("waitTill" IS NOT NULL) AND ("deletedAt" IS NULL));


--
-- Name: idx_execution_entity_workflow_id_started_at; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX idx_execution_entity_workflow_id_started_at ON public.execution_entity USING btree ("workflowId", "startedAt") WHERE (("startedAt" IS NOT NULL) AND ("deletedAt" IS NULL));


--
-- Name: idx_pagos_cliente; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX idx_pagos_cliente ON public.pagos USING btree (id_cliente);


--
-- Name: idx_pagos_fecha; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX idx_pagos_fecha ON public.pagos USING btree (fecha_pago);


--
-- Name: idx_pedidos_cliente; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX idx_pedidos_cliente ON public.pedidos USING btree (id_cliente);


--
-- Name: idx_pedidos_estado; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX idx_pedidos_estado ON public.pedidos USING btree (estado);


--
-- Name: idx_pedidos_fecha; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX idx_pedidos_fecha ON public.pedidos USING btree (fecha_pedido);


--
-- Name: idx_produccion_fecha; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX idx_produccion_fecha ON public.produccion_diaria USING btree (fecha_produccion);


--
-- Name: idx_workflows_tags_workflow_id; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX idx_workflows_tags_workflow_id ON public.workflows_tags USING btree ("workflowId");


--
-- Name: pk_credentials_entity_id; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE UNIQUE INDEX pk_credentials_entity_id ON public.credentials_entity USING btree (id);


--
-- Name: pk_tag_entity_id; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE UNIQUE INDEX pk_tag_entity_id ON public.tag_entity USING btree (id);


--
-- Name: pk_workflow_entity_id; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE UNIQUE INDEX pk_workflow_entity_id ON public.workflow_entity USING btree (id);


--
-- Name: project_relation_role_idx; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX project_relation_role_idx ON public.project_relation USING btree (role);


--
-- Name: project_relation_role_project_idx; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX project_relation_role_project_idx ON public.project_relation USING btree ("projectId", role);


--
-- Name: user_role_idx; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE INDEX user_role_idx ON public."user" USING btree ("roleSlug");


--
-- Name: variables_global_key_unique; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE UNIQUE INDEX variables_global_key_unique ON public.variables USING btree (key) WHERE ("projectId" IS NULL);


--
-- Name: variables_project_key_unique; Type: INDEX; Schema: public; Owner: panif_user
--

CREATE UNIQUE INDEX variables_project_key_unique ON public.variables USING btree ("projectId", key) WHERE ("projectId" IS NOT NULL);


--
-- Name: pagos trg_actualizar_deuda; Type: TRIGGER; Schema: public; Owner: panif_user
--

CREATE TRIGGER trg_actualizar_deuda AFTER INSERT ON public.pagos FOR EACH ROW EXECUTE FUNCTION public.actualizar_estado_deuda();


--
-- Name: workflow_entity workflow_version_increment; Type: TRIGGER; Schema: public; Owner: panif_user
--

CREATE TRIGGER workflow_version_increment BEFORE UPDATE ON public.workflow_entity FOR EACH ROW EXECUTE FUNCTION public.increment_workflow_version();


--
-- Name: workflow_builder_session FK_00290cdeee4d4d7db84709be936; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.workflow_builder_session
    ADD CONSTRAINT "FK_00290cdeee4d4d7db84709be936" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: processed_data FK_06a69a7032c97a763c2c7599464; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.processed_data
    ADD CONSTRAINT "FK_06a69a7032c97a763c2c7599464" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: workflow_entity FK_08d6c67b7f722b0039d9d5ed620; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.workflow_entity
    ADD CONSTRAINT "FK_08d6c67b7f722b0039d9d5ed620" FOREIGN KEY ("activeVersionId") REFERENCES public.workflow_history("versionId") ON DELETE RESTRICT;


--
-- Name: project_secrets_provider_access FK_18e5c27d2524b1638b292904e48; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.project_secrets_provider_access
    ADD CONSTRAINT "FK_18e5c27d2524b1638b292904e48" FOREIGN KEY ("secretsProviderConnectionId") REFERENCES public.secrets_provider_connection(id) ON DELETE CASCADE;


--
-- Name: insights_metadata FK_1d8ab99d5861c9388d2dc1cf733; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.insights_metadata
    ADD CONSTRAINT "FK_1d8ab99d5861c9388d2dc1cf733" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE SET NULL;


--
-- Name: workflow_history FK_1e31657f5fe46816c34be7c1b4b; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.workflow_history
    ADD CONSTRAINT "FK_1e31657f5fe46816c34be7c1b4b" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: chat_hub_messages FK_1f4998c8a7dec9e00a9ab15550e; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_1f4998c8a7dec9e00a9ab15550e" FOREIGN KEY ("revisionOfMessageId") REFERENCES public.chat_hub_messages(id) ON DELETE CASCADE;


--
-- Name: oauth_user_consents FK_21e6c3c2d78a097478fae6aaefa; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.oauth_user_consents
    ADD CONSTRAINT "FK_21e6c3c2d78a097478fae6aaefa" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: insights_metadata FK_2375a1eda085adb16b24615b69c; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.insights_metadata
    ADD CONSTRAINT "FK_2375a1eda085adb16b24615b69c" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE SET NULL;


--
-- Name: chat_hub_messages FK_25c9736e7f769f3a005eef4b372; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_25c9736e7f769f3a005eef4b372" FOREIGN KEY ("retryOfMessageId") REFERENCES public.chat_hub_messages(id) ON DELETE CASCADE;


--
-- Name: chat_hub_agent_tools FK_2b53d796b3dbae91b1a9553c048; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.chat_hub_agent_tools
    ADD CONSTRAINT "FK_2b53d796b3dbae91b1a9553c048" FOREIGN KEY ("agentId") REFERENCES public.chat_hub_agents(id) ON DELETE CASCADE;


--
-- Name: execution_metadata FK_31d0b4c93fb85ced26f6005cda3; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.execution_metadata
    ADD CONSTRAINT "FK_31d0b4c93fb85ced26f6005cda3" FOREIGN KEY ("executionId") REFERENCES public.execution_entity(id) ON DELETE CASCADE;


--
-- Name: shared_credentials FK_416f66fc846c7c442970c094ccf; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.shared_credentials
    ADD CONSTRAINT "FK_416f66fc846c7c442970c094ccf" FOREIGN KEY ("credentialsId") REFERENCES public.credentials_entity(id) ON DELETE CASCADE;


--
-- Name: variables FK_42f6c766f9f9d2edcc15bdd6e9b; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.variables
    ADD CONSTRAINT "FK_42f6c766f9f9d2edcc15bdd6e9b" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: chat_hub_agent_tools FK_43e70f04c53344f82483d0570f6; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.chat_hub_agent_tools
    ADD CONSTRAINT "FK_43e70f04c53344f82483d0570f6" FOREIGN KEY ("toolId") REFERENCES public.chat_hub_tools(id) ON DELETE CASCADE;


--
-- Name: chat_hub_agents FK_441ba2caba11e077ce3fbfa2cd8; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.chat_hub_agents
    ADD CONSTRAINT "FK_441ba2caba11e077ce3fbfa2cd8" FOREIGN KEY ("ownerId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: workflow_published_version FK_5c76fb7ee939fe2530374d3f75a; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.workflow_published_version
    ADD CONSTRAINT "FK_5c76fb7ee939fe2530374d3f75a" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: project_relation FK_5f0643f6717905a05164090dde7; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.project_relation
    ADD CONSTRAINT "FK_5f0643f6717905a05164090dde7" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: project_relation FK_61448d56d61802b5dfde5cdb002; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.project_relation
    ADD CONSTRAINT "FK_61448d56d61802b5dfde5cdb002" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: insights_by_period FK_6414cfed98daabbfdd61a1cfbc0; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.insights_by_period
    ADD CONSTRAINT "FK_6414cfed98daabbfdd61a1cfbc0" FOREIGN KEY ("metaId") REFERENCES public.insights_metadata("metaId") ON DELETE CASCADE;


--
-- Name: oauth_authorization_codes FK_64d965bd072ea24fb6da55468cd; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.oauth_authorization_codes
    ADD CONSTRAINT "FK_64d965bd072ea24fb6da55468cd" FOREIGN KEY ("clientId") REFERENCES public.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: chat_hub_session_tools FK_6596a328affd8d4967ffb303eee; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.chat_hub_session_tools
    ADD CONSTRAINT "FK_6596a328affd8d4967ffb303eee" FOREIGN KEY ("toolId") REFERENCES public.chat_hub_tools(id) ON DELETE CASCADE;


--
-- Name: chat_hub_messages FK_6afb260449dd7a9b85355d4e0c9; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_6afb260449dd7a9b85355d4e0c9" FOREIGN KEY ("executionId") REFERENCES public.execution_entity(id) ON DELETE SET NULL;


--
-- Name: insights_raw FK_6e2e33741adef2a7c5d66befa4e; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.insights_raw
    ADD CONSTRAINT "FK_6e2e33741adef2a7c5d66befa4e" FOREIGN KEY ("metaId") REFERENCES public.insights_metadata("metaId") ON DELETE CASCADE;


--
-- Name: workflow_publish_history FK_6eab5bd9eedabe9c54bd879fc40; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.workflow_publish_history
    ADD CONSTRAINT "FK_6eab5bd9eedabe9c54bd879fc40" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE SET NULL;


--
-- Name: dynamic_credential_user_entry FK_6edec973a6450990977bb854c38; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.dynamic_credential_user_entry
    ADD CONSTRAINT "FK_6edec973a6450990977bb854c38" FOREIGN KEY ("resolverId") REFERENCES public.dynamic_credential_resolver(id) ON DELETE CASCADE;


--
-- Name: oauth_access_tokens FK_7234a36d8e49a1fa85095328845; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.oauth_access_tokens
    ADD CONSTRAINT "FK_7234a36d8e49a1fa85095328845" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: installed_nodes FK_73f857fc5dce682cef8a99c11dbddbc969618951; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.installed_nodes
    ADD CONSTRAINT "FK_73f857fc5dce682cef8a99c11dbddbc969618951" FOREIGN KEY (package) REFERENCES public.installed_packages("packageName") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: oauth_access_tokens FK_78b26968132b7e5e45b75876481; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.oauth_access_tokens
    ADD CONSTRAINT "FK_78b26968132b7e5e45b75876481" FOREIGN KEY ("clientId") REFERENCES public.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: workflow_builder_session FK_7983c618db48f47bf5a4cc1e1e4; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.workflow_builder_session
    ADD CONSTRAINT "FK_7983c618db48f47bf5a4cc1e1e4" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: chat_hub_sessions FK_7bc13b4c7e6afbfaf9be326c189; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.chat_hub_sessions
    ADD CONSTRAINT "FK_7bc13b4c7e6afbfaf9be326c189" FOREIGN KEY ("credentialId") REFERENCES public.credentials_entity(id) ON DELETE SET NULL;


--
-- Name: folder FK_804ea52f6729e3940498bd54d78; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.folder
    ADD CONSTRAINT "FK_804ea52f6729e3940498bd54d78" FOREIGN KEY ("parentFolderId") REFERENCES public.folder(id) ON DELETE CASCADE;


--
-- Name: shared_credentials FK_812c2852270da1247756e77f5a4; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.shared_credentials
    ADD CONSTRAINT "FK_812c2852270da1247756e77f5a4" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: test_case_execution FK_8e4b4774db42f1e6dda3452b2af; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.test_case_execution
    ADD CONSTRAINT "FK_8e4b4774db42f1e6dda3452b2af" FOREIGN KEY ("testRunId") REFERENCES public.test_run(id) ON DELETE CASCADE;


--
-- Name: data_table_column FK_930b6e8faaf88294cef23484160; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.data_table_column
    ADD CONSTRAINT "FK_930b6e8faaf88294cef23484160" FOREIGN KEY ("dataTableId") REFERENCES public.data_table(id) ON DELETE CASCADE;


--
-- Name: dynamic_credential_user_entry FK_945ba70b342a066d1306b12ccd2; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.dynamic_credential_user_entry
    ADD CONSTRAINT "FK_945ba70b342a066d1306b12ccd2" FOREIGN KEY ("credentialId") REFERENCES public.credentials_entity(id) ON DELETE CASCADE;


--
-- Name: folder_tag FK_94a60854e06f2897b2e0d39edba; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.folder_tag
    ADD CONSTRAINT "FK_94a60854e06f2897b2e0d39edba" FOREIGN KEY ("folderId") REFERENCES public.folder(id) ON DELETE CASCADE;


--
-- Name: execution_annotations FK_97f863fa83c4786f19565084960; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.execution_annotations
    ADD CONSTRAINT "FK_97f863fa83c4786f19565084960" FOREIGN KEY ("executionId") REFERENCES public.execution_entity(id) ON DELETE CASCADE;


--
-- Name: chat_hub_agents FK_9c61ad497dcbae499c96a6a78ba; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.chat_hub_agents
    ADD CONSTRAINT "FK_9c61ad497dcbae499c96a6a78ba" FOREIGN KEY ("credentialId") REFERENCES public.credentials_entity(id) ON DELETE SET NULL;


--
-- Name: chat_hub_sessions FK_9f9293d9f552496c40e0d1a8f80; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.chat_hub_sessions
    ADD CONSTRAINT "FK_9f9293d9f552496c40e0d1a8f80" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE SET NULL;


--
-- Name: execution_annotation_tags FK_a3697779b366e131b2bbdae2976; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.execution_annotation_tags
    ADD CONSTRAINT "FK_a3697779b366e131b2bbdae2976" FOREIGN KEY ("tagId") REFERENCES public.annotation_tag_entity(id) ON DELETE CASCADE;


--
-- Name: dynamic_credential_user_entry FK_a36dc616fabc3f736bb82410a22; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.dynamic_credential_user_entry
    ADD CONSTRAINT "FK_a36dc616fabc3f736bb82410a22" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: shared_workflow FK_a45ea5f27bcfdc21af9b4188560; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.shared_workflow
    ADD CONSTRAINT "FK_a45ea5f27bcfdc21af9b4188560" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: workflow_dependency FK_a4ff2d9b9628ea988fa9e7d0bf8; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.workflow_dependency
    ADD CONSTRAINT "FK_a4ff2d9b9628ea988fa9e7d0bf8" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: oauth_user_consents FK_a651acea2f6c97f8c4514935486; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.oauth_user_consents
    ADD CONSTRAINT "FK_a651acea2f6c97f8c4514935486" FOREIGN KEY ("clientId") REFERENCES public.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_refresh_tokens FK_a699f3ed9fd0c1b19bc2608ac53; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.oauth_refresh_tokens
    ADD CONSTRAINT "FK_a699f3ed9fd0c1b19bc2608ac53" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: dynamic_credential_entry FK_a6d1dd080958304a47a02952aab; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.dynamic_credential_entry
    ADD CONSTRAINT "FK_a6d1dd080958304a47a02952aab" FOREIGN KEY (credential_id) REFERENCES public.credentials_entity(id) ON DELETE CASCADE;


--
-- Name: folder FK_a8260b0b36939c6247f385b8221; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.folder
    ADD CONSTRAINT "FK_a8260b0b36939c6247f385b8221" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: oauth_authorization_codes FK_aa8d3560484944c19bdf79ffa16; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.oauth_authorization_codes
    ADD CONSTRAINT "FK_aa8d3560484944c19bdf79ffa16" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: chat_hub_messages FK_acf8926098f063cdbbad8497fd1; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_acf8926098f063cdbbad8497fd1" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE SET NULL;


--
-- Name: oauth_refresh_tokens FK_b388696ce4d8be7ffbe8d3e4b69; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.oauth_refresh_tokens
    ADD CONSTRAINT "FK_b388696ce4d8be7ffbe8d3e4b69" FOREIGN KEY ("clientId") REFERENCES public.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: workflow_publish_history FK_b4cfbc7556d07f36ca177f5e473; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.workflow_publish_history
    ADD CONSTRAINT "FK_b4cfbc7556d07f36ca177f5e473" FOREIGN KEY ("versionId") REFERENCES public.workflow_history("versionId") ON DELETE CASCADE;


--
-- Name: chat_hub_tools FK_b8030b47af9213f1fd15450fb7f; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.chat_hub_tools
    ADD CONSTRAINT "FK_b8030b47af9213f1fd15450fb7f" FOREIGN KEY ("ownerId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: project_secrets_provider_access FK_bd264b81209355b543878deedb1; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.project_secrets_provider_access
    ADD CONSTRAINT "FK_bd264b81209355b543878deedb1" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: workflow_publish_history FK_c01316f8c2d7101ec4fa9809267; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.workflow_publish_history
    ADD CONSTRAINT "FK_c01316f8c2d7101ec4fa9809267" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: execution_annotation_tags FK_c1519757391996eb06064f0e7c8; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.execution_annotation_tags
    ADD CONSTRAINT "FK_c1519757391996eb06064f0e7c8" FOREIGN KEY ("annotationId") REFERENCES public.execution_annotations(id) ON DELETE CASCADE;


--
-- Name: data_table FK_c2a794257dee48af7c9abf681de; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.data_table
    ADD CONSTRAINT "FK_c2a794257dee48af7c9abf681de" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: project_relation FK_c6b99592dc96b0d836d7a21db91; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.project_relation
    ADD CONSTRAINT "FK_c6b99592dc96b0d836d7a21db91" FOREIGN KEY (role) REFERENCES public.role(slug);


--
-- Name: chat_hub_messages FK_chat_hub_messages_agentId; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_chat_hub_messages_agentId" FOREIGN KEY ("agentId") REFERENCES public.chat_hub_agents(id) ON DELETE SET NULL;


--
-- Name: chat_hub_sessions FK_chat_hub_sessions_agentId; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.chat_hub_sessions
    ADD CONSTRAINT "FK_chat_hub_sessions_agentId" FOREIGN KEY ("agentId") REFERENCES public.chat_hub_agents(id) ON DELETE SET NULL;


--
-- Name: dynamic_credential_entry FK_d61a12235d268a49af6a3c09c13; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.dynamic_credential_entry
    ADD CONSTRAINT "FK_d61a12235d268a49af6a3c09c13" FOREIGN KEY (resolver_id) REFERENCES public.dynamic_credential_resolver(id) ON DELETE CASCADE;


--
-- Name: test_run FK_d6870d3b6e4c185d33926f423c8; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.test_run
    ADD CONSTRAINT "FK_d6870d3b6e4c185d33926f423c8" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: shared_workflow FK_daa206a04983d47d0a9c34649ce; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.shared_workflow
    ADD CONSTRAINT "FK_daa206a04983d47d0a9c34649ce" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: folder_tag FK_dc88164176283de80af47621746; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.folder_tag
    ADD CONSTRAINT "FK_dc88164176283de80af47621746" FOREIGN KEY ("tagId") REFERENCES public.tag_entity(id) ON DELETE CASCADE;


--
-- Name: workflow_published_version FK_df3428a541b802d6a63ac56e330; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.workflow_published_version
    ADD CONSTRAINT "FK_df3428a541b802d6a63ac56e330" FOREIGN KEY ("publishedVersionId") REFERENCES public.workflow_history("versionId") ON DELETE CASCADE;


--
-- Name: user_api_keys FK_e131705cbbc8fb589889b02d457; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.user_api_keys
    ADD CONSTRAINT "FK_e131705cbbc8fb589889b02d457" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: chat_hub_messages FK_e22538eb50a71a17954cd7e076c; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_e22538eb50a71a17954cd7e076c" FOREIGN KEY ("sessionId") REFERENCES public.chat_hub_sessions(id) ON DELETE CASCADE;


--
-- Name: test_case_execution FK_e48965fac35d0f5b9e7f51d8c44; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.test_case_execution
    ADD CONSTRAINT "FK_e48965fac35d0f5b9e7f51d8c44" FOREIGN KEY ("executionId") REFERENCES public.execution_entity(id) ON DELETE SET NULL;


--
-- Name: chat_hub_messages FK_e5d1fa722c5a8d38ac204746662; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_e5d1fa722c5a8d38ac204746662" FOREIGN KEY ("previousMessageId") REFERENCES public.chat_hub_messages(id) ON DELETE CASCADE;


--
-- Name: chat_hub_session_tools FK_e649bf1295f4ed8d4299ed290f9; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.chat_hub_session_tools
    ADD CONSTRAINT "FK_e649bf1295f4ed8d4299ed290f9" FOREIGN KEY ("sessionId") REFERENCES public.chat_hub_sessions(id) ON DELETE CASCADE;


--
-- Name: chat_hub_sessions FK_e9ecf8ede7d989fcd18790fe36a; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.chat_hub_sessions
    ADD CONSTRAINT "FK_e9ecf8ede7d989fcd18790fe36a" FOREIGN KEY ("ownerId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: user FK_eaea92ee7bfb9c1b6cd01505d56; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT "FK_eaea92ee7bfb9c1b6cd01505d56" FOREIGN KEY ("roleSlug") REFERENCES public.role(slug);


--
-- Name: role_scope FK_role; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.role_scope
    ADD CONSTRAINT "FK_role" FOREIGN KEY ("roleSlug") REFERENCES public.role(slug) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: role_scope FK_scope; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.role_scope
    ADD CONSTRAINT "FK_scope" FOREIGN KEY ("scopeSlug") REFERENCES public.scope(slug) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: auth_identity auth_identity_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.auth_identity
    ADD CONSTRAINT "auth_identity_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."user"(id);


--
-- Name: credentials_entity credentials_entity_resolverId_foreign; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.credentials_entity
    ADD CONSTRAINT "credentials_entity_resolverId_foreign" FOREIGN KEY ("resolverId") REFERENCES public.dynamic_credential_resolver(id) ON DELETE SET NULL;


--
-- Name: detalle_pedidos detalle_pedidos_id_pedido_fkey; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.detalle_pedidos
    ADD CONSTRAINT detalle_pedidos_id_pedido_fkey FOREIGN KEY (id_pedido) REFERENCES public.pedidos(id_pedido) ON DELETE CASCADE;


--
-- Name: deudas deudas_id_cliente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.deudas
    ADD CONSTRAINT deudas_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.clientes(id_cliente);


--
-- Name: deudas deudas_id_pedido_fkey; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.deudas
    ADD CONSTRAINT deudas_id_pedido_fkey FOREIGN KEY (id_pedido) REFERENCES public.pedidos(id_pedido);


--
-- Name: execution_data execution_data_fk; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.execution_data
    ADD CONSTRAINT execution_data_fk FOREIGN KEY ("executionId") REFERENCES public.execution_entity(id) ON DELETE CASCADE;


--
-- Name: execution_entity fk_execution_entity_workflow_id; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.execution_entity
    ADD CONSTRAINT fk_execution_entity_workflow_id FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: productos fk_tipo_masa; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.productos
    ADD CONSTRAINT fk_tipo_masa FOREIGN KEY (tipo_masa) REFERENCES public.tipos_masa(tipo_masa);


--
-- Name: webhook_entity fk_webhook_entity_workflow_id; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.webhook_entity
    ADD CONSTRAINT fk_webhook_entity_workflow_id FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: workflow_entity fk_workflow_parent_folder; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.workflow_entity
    ADD CONSTRAINT fk_workflow_parent_folder FOREIGN KEY ("parentFolderId") REFERENCES public.folder(id) ON DELETE CASCADE;


--
-- Name: workflows_tags fk_workflows_tags_tag_id; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.workflows_tags
    ADD CONSTRAINT fk_workflows_tags_tag_id FOREIGN KEY ("tagId") REFERENCES public.tag_entity(id) ON DELETE CASCADE;


--
-- Name: workflows_tags fk_workflows_tags_workflow_id; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.workflows_tags
    ADD CONSTRAINT fk_workflows_tags_workflow_id FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: pagos pagos_id_cliente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT pagos_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.clientes(id_cliente);


--
-- Name: pagos pagos_id_deuda_fkey; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT pagos_id_deuda_fkey FOREIGN KEY (id_deuda) REFERENCES public.deudas(id_deuda);


--
-- Name: pedidos pedidos_id_cliente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.pedidos
    ADD CONSTRAINT pedidos_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.clientes(id_cliente);


--
-- Name: produccion_diaria produccion_diaria_id_pedido_fkey; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.produccion_diaria
    ADD CONSTRAINT produccion_diaria_id_pedido_fkey FOREIGN KEY (id_pedido) REFERENCES public.pedidos(id_pedido);


--
-- Name: project projects_creatorId_foreign; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.project
    ADD CONSTRAINT "projects_creatorId_foreign" FOREIGN KEY ("creatorId") REFERENCES public."user"(id) ON DELETE SET NULL;


--
-- Name: recetas_masa recetas_masa_tipo_masa_fkey; Type: FK CONSTRAINT; Schema: public; Owner: panif_user
--

ALTER TABLE ONLY public.recetas_masa
    ADD CONSTRAINT recetas_masa_tipo_masa_fkey FOREIGN KEY (tipo_masa) REFERENCES public.tipos_masa(tipo_masa);


--
-- PostgreSQL database dump complete
--

\unrestrict kwep6xZgKsTmfORnBj2zdp2I1U2gQbSMXCYfG27xM5UNGvw8uC5U6ldcttIA6bb

