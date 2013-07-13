--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- Name: plpgsql; Type: PROCEDURAL LANGUAGE; Schema: -; Owner: -
--

CREATE PROCEDURAL LANGUAGE plpgsql;


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: chadoprop; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE chadoprop (
    chadoprop_id integer NOT NULL,
    type_id integer NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE chadoprop; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE chadoprop IS 'This table is different from other prop tables in the database, as it is for storing information about the database itself, like schema version';


--
-- Name: COLUMN chadoprop.type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN chadoprop.type_id IS 'The name of the property or slot is a cvterm. The meaning of the property is defined in that cvterm.';


--
-- Name: COLUMN chadoprop.value; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN chadoprop.value IS 'The value of the property, represented as text. Numeric values are converted to their text representation.';


--
-- Name: COLUMN chadoprop.rank; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN chadoprop.rank IS 'Property-Value ordering. Any
cv can have multiple values for any particular property type -
these are ordered in a list using rank, counting from zero. For
properties that are single-valued rather than multi-valued, the
default 0 value should be used.';


--
-- Name: chadoprop_chadoprop_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE chadoprop_chadoprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: chadoprop_chadoprop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE chadoprop_chadoprop_id_seq OWNED BY chadoprop.chadoprop_id;


--
-- Name: contact; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE contact (
    contact_id integer NOT NULL,
    type_id integer,
    name character varying(255) NOT NULL,
    description character varying(255)
);


--
-- Name: TABLE contact; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE contact IS 'Model persons, institutes, groups, organizations, etc.';


--
-- Name: COLUMN contact.type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN contact.type_id IS 'What type of contact is this?  E.g. "person", "lab".';


--
-- Name: contact_contact_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE contact_contact_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: contact_contact_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE contact_contact_id_seq OWNED BY contact.contact_id;


--
-- Name: contact_relationship; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE contact_relationship (
    contact_relationship_id integer NOT NULL,
    type_id integer NOT NULL,
    subject_id integer NOT NULL,
    object_id integer NOT NULL
);


--
-- Name: TABLE contact_relationship; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE contact_relationship IS 'Model relationships between contacts';


--
-- Name: COLUMN contact_relationship.type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN contact_relationship.type_id IS 'Relationship type between subject and object. This is a cvterm, typically from the OBO relationship ontology, although other relationship types are allowed.';


--
-- Name: COLUMN contact_relationship.subject_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN contact_relationship.subject_id IS 'The subject of the subj-predicate-obj sentence. In a DAG, this corresponds to the child node.';


--
-- Name: COLUMN contact_relationship.object_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN contact_relationship.object_id IS 'The object of the subj-predicate-obj sentence. In a DAG, this corresponds to the parent node.';


--
-- Name: contact_relationship_contact_relationship_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE contact_relationship_contact_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: contact_relationship_contact_relationship_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE contact_relationship_contact_relationship_id_seq OWNED BY contact_relationship.contact_relationship_id;


--
-- Name: cv; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE cv (
    cv_id integer NOT NULL,
    name character varying(255) NOT NULL,
    definition text
);


--
-- Name: TABLE cv; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE cv IS 'A controlled vocabulary or ontology. A cv is
composed of cvterms (AKA terms, classes, types, universals - relations
and properties are also stored in cvterm) and the relationships
between them.';


--
-- Name: COLUMN cv.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN cv.name IS 'The name of the ontology. This
corresponds to the obo-format -namespace-. cv names uniquely identify
the cv. In OBO file format, the cv.name is known as the namespace.';


--
-- Name: COLUMN cv.definition; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN cv.definition IS 'A text description of the criteria for
membership of this ontology.';


--
-- Name: cv_cv_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE cv_cv_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: cv_cv_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE cv_cv_id_seq OWNED BY cv.cv_id;


--
-- Name: cvprop; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE cvprop (
    cvprop_id integer NOT NULL,
    cv_id integer NOT NULL,
    type_id integer NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE cvprop; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE cvprop IS 'Additional extensible properties can be attached to a cv using this table.  A notable example would be the cv version';


--
-- Name: COLUMN cvprop.type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN cvprop.type_id IS 'The name of the property or slot is a cvterm. The meaning of the property is defined in that cvterm.';


--
-- Name: COLUMN cvprop.value; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN cvprop.value IS 'The value of the property, represented as text. Numeric values are converted to their text representation.';


--
-- Name: COLUMN cvprop.rank; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN cvprop.rank IS 'Property-Value ordering. Any
cv can have multiple values for any particular property type -
these are ordered in a list using rank, counting from zero. For
properties that are single-valued rather than multi-valued, the
default 0 value should be used.';


--
-- Name: cvprop_cvprop_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE cvprop_cvprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: cvprop_cvprop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE cvprop_cvprop_id_seq OWNED BY cvprop.cvprop_id;


--
-- Name: cvterm; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE cvterm (
    cvterm_id integer NOT NULL,
    cv_id integer NOT NULL,
    name character varying(1024) NOT NULL,
    definition text,
    dbxref_id integer NOT NULL,
    is_obsolete integer DEFAULT 0 NOT NULL,
    is_relationshiptype integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE cvterm; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE cvterm IS 'A term, class, universal or type within an
ontology or controlled vocabulary.  This table is also used for
relations and properties. cvterms constitute nodes in the graph
defined by the collection of cvterms and cvterm_relationships.';


--
-- Name: COLUMN cvterm.cv_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN cvterm.cv_id IS 'The cv or ontology or namespace to which
this cvterm belongs.';


--
-- Name: COLUMN cvterm.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN cvterm.name IS 'A concise human-readable name or
label for the cvterm. Uniquely identifies a cvterm within a cv.';


--
-- Name: COLUMN cvterm.definition; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN cvterm.definition IS 'A human-readable text
definition.';


--
-- Name: COLUMN cvterm.dbxref_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN cvterm.dbxref_id IS 'Primary identifier dbxref - The
unique global OBO identifier for this cvterm.  Note that a cvterm may
have multiple secondary dbxrefs - see also table: cvterm_dbxref.';


--
-- Name: COLUMN cvterm.is_obsolete; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN cvterm.is_obsolete IS 'Boolean 0=false,1=true; see
GO documentation for details of obsoletion. Note that two terms with
different primary dbxrefs may exist if one is obsolete.';


--
-- Name: COLUMN cvterm.is_relationshiptype; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN cvterm.is_relationshiptype IS 'Boolean
0=false,1=true relations or relationship types (also known as Typedefs
in OBO format, or as properties or slots) form a cv/ontology in
themselves. We use this flag to indicate whether this cvterm is an
actual term/class/universal or a relation. Relations may be drawn from
the OBO Relations ontology, but are not exclusively drawn from there.';


--
-- Name: cvterm_cvterm_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE cvterm_cvterm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: cvterm_cvterm_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE cvterm_cvterm_id_seq OWNED BY cvterm.cvterm_id;


--
-- Name: cvterm_dbxref; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE cvterm_dbxref (
    cvterm_dbxref_id integer NOT NULL,
    cvterm_id integer NOT NULL,
    dbxref_id integer NOT NULL,
    is_for_definition integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE cvterm_dbxref; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE cvterm_dbxref IS 'In addition to the primary
identifier (cvterm.dbxref_id) a cvterm can have zero or more secondary
identifiers/dbxrefs, which may refer to records in external
databases. The exact semantics of cvterm_dbxref are not fixed. For
example: the dbxref could be a pubmed ID that is pertinent to the
cvterm, or it could be an equivalent or similar term in another
ontology. For example, GO cvterms are typically linked to InterPro
IDs, even though the nature of the relationship between them is
largely one of statistical association. The dbxref may be have data
records attached in the same database instance, or it could be a
"hanging" dbxref pointing to some external database. NOTE: If the
desired objective is to link two cvterms together, and the nature of
the relation is known and holds for all instances of the subject
cvterm then consider instead using cvterm_relationship together with a
well-defined relation.';


--
-- Name: COLUMN cvterm_dbxref.is_for_definition; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN cvterm_dbxref.is_for_definition IS 'A
cvterm.definition should be supported by one or more references. If
this column is true, the dbxref is not for a term in an external database -
it is a dbxref for provenance information for the definition.';


--
-- Name: cvterm_dbxref_cvterm_dbxref_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE cvterm_dbxref_cvterm_dbxref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: cvterm_dbxref_cvterm_dbxref_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE cvterm_dbxref_cvterm_dbxref_id_seq OWNED BY cvterm_dbxref.cvterm_dbxref_id;


--
-- Name: cvterm_relationship; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE cvterm_relationship (
    cvterm_relationship_id integer NOT NULL,
    type_id integer NOT NULL,
    subject_id integer NOT NULL,
    object_id integer NOT NULL
);


--
-- Name: TABLE cvterm_relationship; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE cvterm_relationship IS 'A relationship linking two
cvterms. Each cvterm_relationship constitutes an edge in the graph
defined by the collection of cvterms and cvterm_relationships. The
meaning of the cvterm_relationship depends on the definition of the
cvterm R refered to by type_id. However, in general the definitions
are such that the statement "all SUBJs REL some OBJ" is true. The
cvterm_relationship statement is about the subject, not the
object. For example "insect wing part_of thorax".';


--
-- Name: COLUMN cvterm_relationship.type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN cvterm_relationship.type_id IS 'The nature of the
relationship between subject and object. Note that relations are also
housed in the cvterm table, typically from the OBO relationship
ontology, although other relationship types are allowed.';


--
-- Name: COLUMN cvterm_relationship.subject_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN cvterm_relationship.subject_id IS 'The subject of
the subj-predicate-obj sentence. The cvterm_relationship is about the
subject. In a graph, this typically corresponds to the child node.';


--
-- Name: COLUMN cvterm_relationship.object_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN cvterm_relationship.object_id IS 'The object of the
subj-predicate-obj sentence. The cvterm_relationship refers to the
object. In a graph, this typically corresponds to the parent node.';


--
-- Name: cvterm_relationship_cvterm_relationship_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE cvterm_relationship_cvterm_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: cvterm_relationship_cvterm_relationship_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE cvterm_relationship_cvterm_relationship_id_seq OWNED BY cvterm_relationship.cvterm_relationship_id;


--
-- Name: cvtermpath; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE cvtermpath (
    cvtermpath_id integer NOT NULL,
    type_id integer,
    subject_id integer NOT NULL,
    object_id integer NOT NULL,
    cv_id integer NOT NULL,
    pathdistance integer
);


--
-- Name: TABLE cvtermpath; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE cvtermpath IS 'The reflexive transitive closure of
the cvterm_relationship relation.';


--
-- Name: COLUMN cvtermpath.type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN cvtermpath.type_id IS 'The relationship type that
this is a closure over. If null, then this is a closure over ALL
relationship types. If non-null, then this references a relationship
cvterm - note that the closure will apply to both this relationship
AND the OBO_REL:is_a (subclass) relationship.';


--
-- Name: COLUMN cvtermpath.cv_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN cvtermpath.cv_id IS 'Closures will mostly be within
one cv. If the closure of a relationship traverses a cv, then this
refers to the cv of the object_id cvterm.';


--
-- Name: COLUMN cvtermpath.pathdistance; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN cvtermpath.pathdistance IS 'The number of steps
required to get from the subject cvterm to the object cvterm, counting
from zero (reflexive relationship).';


--
-- Name: cvtermpath_cvtermpath_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE cvtermpath_cvtermpath_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: cvtermpath_cvtermpath_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE cvtermpath_cvtermpath_id_seq OWNED BY cvtermpath.cvtermpath_id;


--
-- Name: cvtermprop; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE cvtermprop (
    cvtermprop_id integer NOT NULL,
    cvterm_id integer NOT NULL,
    type_id integer NOT NULL,
    value text DEFAULT ''::text NOT NULL,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE cvtermprop; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE cvtermprop IS 'Additional extensible properties can be attached to a cvterm using this table. Corresponds to -AnnotationProperty- in W3C OWL format.';


--
-- Name: COLUMN cvtermprop.type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN cvtermprop.type_id IS 'The name of the property or slot is a cvterm. The meaning of the property is defined in that cvterm.';


--
-- Name: COLUMN cvtermprop.value; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN cvtermprop.value IS 'The value of the property, represented as text. Numeric values are converted to their text representation.';


--
-- Name: COLUMN cvtermprop.rank; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN cvtermprop.rank IS 'Property-Value ordering. Any
cvterm can have multiple values for any particular property type -
these are ordered in a list using rank, counting from zero. For
properties that are single-valued rather than multi-valued, the
default 0 value should be used.';


--
-- Name: cvtermprop_cvtermprop_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE cvtermprop_cvtermprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: cvtermprop_cvtermprop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE cvtermprop_cvtermprop_id_seq OWNED BY cvtermprop.cvtermprop_id;


--
-- Name: cvtermsynonym; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE cvtermsynonym (
    cvtermsynonym_id integer NOT NULL,
    cvterm_id integer NOT NULL,
    synonym character varying(1024) NOT NULL,
    type_id integer
);


--
-- Name: TABLE cvtermsynonym; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE cvtermsynonym IS 'A cvterm actually represents a
distinct class or concept. A concept can be refered to by different
phrases or names. In addition to the primary name (cvterm.name) there
can be a number of alternative aliases or synonyms. For example, "T
cell" as a synonym for "T lymphocyte".';


--
-- Name: COLUMN cvtermsynonym.type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN cvtermsynonym.type_id IS 'A synonym can be exact,
narrower, or broader than.';


--
-- Name: cvtermsynonym_cvtermsynonym_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE cvtermsynonym_cvtermsynonym_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: cvtermsynonym_cvtermsynonym_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE cvtermsynonym_cvtermsynonym_id_seq OWNED BY cvtermsynonym.cvtermsynonym_id;


--
-- Name: db; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE db (
    db_id integer NOT NULL,
    name character varying(255) NOT NULL,
    description character varying(255),
    urlprefix character varying(255),
    url character varying(255)
);


--
-- Name: TABLE db; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE db IS 'A database authority. Typical databases in
bioinformatics are FlyBase, GO, UniProt, NCBI, MGI, etc. The authority
is generally known by this shortened form, which is unique within the
bioinformatics and biomedical realm.  To Do - add support for URIs,
URNs (e.g. LSIDs). We can do this by treating the URL as a URI -
however, some applications may expect this to be resolvable - to be
decided.';


--
-- Name: db_db_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE db_db_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: db_db_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE db_db_id_seq OWNED BY db.db_id;


--
-- Name: dbxref; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE dbxref (
    dbxref_id integer NOT NULL,
    db_id integer NOT NULL,
    accession character varying(1024) NOT NULL,
    version character varying(255) DEFAULT ''::character varying NOT NULL,
    description text
);


--
-- Name: TABLE dbxref; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE dbxref IS 'A unique, global, public, stable identifier. Not necessarily an external reference - can reference data items inside the particular chado instance being used. Typically a row in a table can be uniquely identified with a primary identifier (called dbxref_id); a table may also have secondary identifiers (in a linking table <T>_dbxref). A dbxref is generally written as <DB>:<ACCESSION> or as <DB>:<ACCESSION>:<VERSION>.';


--
-- Name: COLUMN dbxref.accession; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN dbxref.accession IS 'The local part of the identifier. Guaranteed by the db authority to be unique for that db.';


--
-- Name: dbxref_dbxref_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE dbxref_dbxref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: dbxref_dbxref_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE dbxref_dbxref_id_seq OWNED BY dbxref.dbxref_id;


--
-- Name: dbxrefprop; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE dbxrefprop (
    dbxrefprop_id integer NOT NULL,
    dbxref_id integer NOT NULL,
    type_id integer NOT NULL,
    value text DEFAULT ''::text NOT NULL,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE dbxrefprop; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE dbxrefprop IS 'Metadata about a dbxref. Note that this is not defined in the dbxref module, as it depends on the cvterm table. This table has a structure analagous to cvtermprop.';


--
-- Name: dbxrefprop_dbxrefprop_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE dbxrefprop_dbxrefprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: dbxrefprop_dbxrefprop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE dbxrefprop_dbxrefprop_id_seq OWNED BY dbxrefprop.dbxrefprop_id;


--
-- Name: environment; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE environment (
    environment_id integer NOT NULL,
    uniquename text NOT NULL,
    description text
);


--
-- Name: TABLE environment; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE environment IS 'The environmental component of a phenotype description.';


--
-- Name: environment_cvterm; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE environment_cvterm (
    environment_cvterm_id integer NOT NULL,
    environment_id integer NOT NULL,
    cvterm_id integer NOT NULL
);


--
-- Name: environment_cvterm_environment_cvterm_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE environment_cvterm_environment_cvterm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: environment_cvterm_environment_cvterm_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE environment_cvterm_environment_cvterm_id_seq OWNED BY environment_cvterm.environment_cvterm_id;


--
-- Name: environment_environment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE environment_environment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: environment_environment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE environment_environment_id_seq OWNED BY environment.environment_id;


--
-- Name: feature; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE feature (
    feature_id integer NOT NULL,
    dbxref_id integer,
    organism_id integer NOT NULL,
    name character varying(255),
    uniquename text NOT NULL,
    residues text,
    seqlen integer,
    md5checksum character(32),
    type_id integer NOT NULL,
    is_analysis boolean DEFAULT false NOT NULL,
    is_obsolete boolean DEFAULT false NOT NULL,
    timeaccessioned timestamp without time zone DEFAULT now() NOT NULL,
    timelastmodified timestamp without time zone DEFAULT now() NOT NULL
);
ALTER TABLE ONLY feature ALTER COLUMN residues SET STORAGE EXTERNAL;


--
-- Name: TABLE feature; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE feature IS 'A feature is a biological sequence or a
section of a biological sequence, or a collection of such
sections. Examples include genes, exons, transcripts, regulatory
regions, polypeptides, protein domains, chromosome sequences, sequence
variations, cross-genome match regions such as hits and HSPs and so
on; see the Sequence Ontology for more. The combination of
organism_id, uniquename and type_id should be unique.';


--
-- Name: COLUMN feature.dbxref_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature.dbxref_id IS 'An optional primary public stable
identifier for this feature. Secondary identifiers and external
dbxrefs go in the table feature_dbxref.';


--
-- Name: COLUMN feature.organism_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature.organism_id IS 'The organism to which this feature
belongs. This column is mandatory.';


--
-- Name: COLUMN feature.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature.name IS 'The optional human-readable common name for
a feature, for display purposes.';


--
-- Name: COLUMN feature.uniquename; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature.uniquename IS 'The unique name for a feature; may
not be necessarily be particularly human-readable, although this is
preferred. This name must be unique for this type of feature within
this organism.';


--
-- Name: COLUMN feature.residues; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature.residues IS 'A sequence of alphabetic characters
representing biological residues (nucleic acids, amino acids). This
column does not need to be manifested for all features; it is optional
for features such as exons where the residues can be derived from the
featureloc. It is recommended that the value for this column be
manifested for features which may may non-contiguous sublocations (e.g.
transcripts), since derivation at query time is non-trivial. For
expressed sequence, the DNA sequence should be used rather than the
RNA sequence. The default storage method for the residues column is
EXTERNAL, which will store it uncompressed to make substring operations
faster.';


--
-- Name: COLUMN feature.seqlen; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature.seqlen IS 'The length of the residue feature. See
column:residues. This column is partially redundant with the residues
column, and also with featureloc. This column is required because the
location may be unknown and the residue sequence may not be
manifested, yet it may be desirable to store and query the length of
the feature. The seqlen should always be manifested where the length
of the sequence is known.';


--
-- Name: COLUMN feature.md5checksum; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature.md5checksum IS 'The 32-character checksum of the sequence,
calculated using the MD5 algorithm. This is practically guaranteed to
be unique for any feature. This column thus acts as a unique
identifier on the mathematical sequence.';


--
-- Name: COLUMN feature.type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature.type_id IS 'A required reference to a table:cvterm
giving the feature type. This will typically be a Sequence Ontology
identifier. This column is thus used to subclass the feature table.';


--
-- Name: COLUMN feature.is_analysis; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature.is_analysis IS 'Boolean indicating whether this
feature is annotated or the result of an automated analysis. Analysis
results also use the companalysis module. Note that the dividing line
between analysis and annotation may be fuzzy, this should be determined on
a per-project basis in a consistent manner. One requirement is that
there should only be one non-analysis version of each wild-type gene
feature in a genome, whereas the same gene feature can be predicted
multiple times in different analyses.';


--
-- Name: COLUMN feature.is_obsolete; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature.is_obsolete IS 'Boolean indicating whether this
feature has been obsoleted. Some chado instances may choose to simply
remove the feature altogether, others may choose to keep an obsolete
row in the table.';


--
-- Name: COLUMN feature.timeaccessioned; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature.timeaccessioned IS 'For handling object
accession or modification timestamps (as opposed to database auditing data,
handled elsewhere). The expectation is that these fields would be
available to software interacting with chado.';


--
-- Name: COLUMN feature.timelastmodified; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature.timelastmodified IS 'For handling object
accession or modification timestamps (as opposed to database auditing data,
handled elsewhere). The expectation is that these fields would be
available to software interacting with chado.';


--
-- Name: feature_cvterm; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE feature_cvterm (
    feature_cvterm_id integer NOT NULL,
    feature_id integer NOT NULL,
    cvterm_id integer NOT NULL,
    pub_id integer NOT NULL,
    is_not boolean DEFAULT false NOT NULL,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE feature_cvterm; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE feature_cvterm IS 'Associate a term from a cv with a feature, for example, GO annotation.';


--
-- Name: COLUMN feature_cvterm.pub_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature_cvterm.pub_id IS 'Provenance for the annotation. Each annotation should have a single primary publication (which may be of the appropriate type for computational analyses) where more details can be found. Additional provenance dbxrefs can be attached using feature_cvterm_dbxref.';


--
-- Name: COLUMN feature_cvterm.is_not; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature_cvterm.is_not IS 'If this is set to true, then this annotation is interpreted as a NEGATIVE annotation - i.e. the feature does NOT have the specified function, process, component, part, etc. See GO docs for more details.';


--
-- Name: feature_cvterm_dbxref; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE feature_cvterm_dbxref (
    feature_cvterm_dbxref_id integer NOT NULL,
    feature_cvterm_id integer NOT NULL,
    dbxref_id integer NOT NULL
);


--
-- Name: TABLE feature_cvterm_dbxref; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE feature_cvterm_dbxref IS 'Additional dbxrefs for an association. Rows in the feature_cvterm table may be backed up by dbxrefs. For example, a feature_cvterm association that was inferred via a protein-protein interaction may be backed by by refering to the dbxref for the alternate protein. Corresponds to the WITH column in a GO gene association file (but can also be used for other analagous associations). See http://www.geneontology.org/doc/GO.annotation.shtml#file for more details.';


--
-- Name: feature_cvterm_dbxref_feature_cvterm_dbxref_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE feature_cvterm_dbxref_feature_cvterm_dbxref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: feature_cvterm_dbxref_feature_cvterm_dbxref_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE feature_cvterm_dbxref_feature_cvterm_dbxref_id_seq OWNED BY feature_cvterm_dbxref.feature_cvterm_dbxref_id;


--
-- Name: feature_cvterm_feature_cvterm_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE feature_cvterm_feature_cvterm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: feature_cvterm_feature_cvterm_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE feature_cvterm_feature_cvterm_id_seq OWNED BY feature_cvterm.feature_cvterm_id;


--
-- Name: feature_cvterm_pub; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE feature_cvterm_pub (
    feature_cvterm_pub_id integer NOT NULL,
    feature_cvterm_id integer NOT NULL,
    pub_id integer NOT NULL
);


--
-- Name: TABLE feature_cvterm_pub; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE feature_cvterm_pub IS 'Secondary pubs for an
association. Each feature_cvterm association is supported by a single
primary publication. Additional secondary pubs can be added using this
linking table (in a GO gene association file, these corresponding to
any IDs after the pipe symbol in the publications column.';


--
-- Name: feature_cvterm_pub_feature_cvterm_pub_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE feature_cvterm_pub_feature_cvterm_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: feature_cvterm_pub_feature_cvterm_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE feature_cvterm_pub_feature_cvterm_pub_id_seq OWNED BY feature_cvterm_pub.feature_cvterm_pub_id;


--
-- Name: feature_cvtermprop; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE feature_cvtermprop (
    feature_cvtermprop_id integer NOT NULL,
    feature_cvterm_id integer NOT NULL,
    type_id integer NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE feature_cvtermprop; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE feature_cvtermprop IS 'Extensible properties for
feature to cvterm associations. Examples: GO evidence codes;
qualifiers; metadata such as the date on which the entry was curated
and the source of the association. See the featureprop table for
meanings of type_id, value and rank.';


--
-- Name: COLUMN feature_cvtermprop.type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature_cvtermprop.type_id IS 'The name of the
property/slot is a cvterm. The meaning of the property is defined in
that cvterm. cvterms may come from the OBO evidence code cv.';


--
-- Name: COLUMN feature_cvtermprop.value; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature_cvtermprop.value IS 'The value of the
property, represented as text. Numeric values are converted to their
text representation. This is less efficient than using native database
types, but is easier to query.';


--
-- Name: COLUMN feature_cvtermprop.rank; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature_cvtermprop.rank IS 'Property-Value
ordering. Any feature_cvterm can have multiple values for any particular
property type - these are ordered in a list using rank, counting from
zero. For properties that are single-valued rather than multi-valued,
the default 0 value should be used.';


--
-- Name: feature_cvtermprop_feature_cvtermprop_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE feature_cvtermprop_feature_cvtermprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: feature_cvtermprop_feature_cvtermprop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE feature_cvtermprop_feature_cvtermprop_id_seq OWNED BY feature_cvtermprop.feature_cvtermprop_id;


--
-- Name: feature_dbxref; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE feature_dbxref (
    feature_dbxref_id integer NOT NULL,
    feature_id integer NOT NULL,
    dbxref_id integer NOT NULL,
    is_current boolean DEFAULT true NOT NULL
);


--
-- Name: TABLE feature_dbxref; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE feature_dbxref IS 'Links a feature to dbxrefs. This is for secondary identifiers; primary identifiers should use feature.dbxref_id.';


--
-- Name: COLUMN feature_dbxref.is_current; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature_dbxref.is_current IS 'True if this secondary dbxref is the most up to date accession in the corresponding db. Retired accessions should set this field to false';


--
-- Name: feature_dbxref_feature_dbxref_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE feature_dbxref_feature_dbxref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: feature_dbxref_feature_dbxref_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE feature_dbxref_feature_dbxref_id_seq OWNED BY feature_dbxref.feature_dbxref_id;


--
-- Name: feature_feature_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE feature_feature_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: feature_feature_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE feature_feature_id_seq OWNED BY feature.feature_id;


--
-- Name: feature_genotype; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE feature_genotype (
    feature_genotype_id integer NOT NULL,
    feature_id integer NOT NULL,
    genotype_id integer NOT NULL,
    chromosome_id integer,
    rank integer NOT NULL,
    cgroup integer NOT NULL,
    cvterm_id integer NOT NULL
);


--
-- Name: COLUMN feature_genotype.chromosome_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature_genotype.chromosome_id IS 'A feature of SO type "chromosome".';


--
-- Name: COLUMN feature_genotype.rank; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature_genotype.rank IS 'rank can be used for
n-ploid organisms or to preserve order.';


--
-- Name: COLUMN feature_genotype.cgroup; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature_genotype.cgroup IS 'Spatially distinguishable
group. group can be used for distinguishing the chromosomal groups,
for example (RNAi products and so on can be treated as different
groups, as they do not fall on a particular chromosome).';


--
-- Name: feature_genotype_feature_genotype_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE feature_genotype_feature_genotype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: feature_genotype_feature_genotype_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE feature_genotype_feature_genotype_id_seq OWNED BY feature_genotype.feature_genotype_id;


--
-- Name: feature_phenotype; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE feature_phenotype (
    feature_phenotype_id integer NOT NULL,
    feature_id integer NOT NULL,
    phenotype_id integer NOT NULL
);


--
-- Name: feature_phenotype_feature_phenotype_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE feature_phenotype_feature_phenotype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: feature_phenotype_feature_phenotype_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE feature_phenotype_feature_phenotype_id_seq OWNED BY feature_phenotype.feature_phenotype_id;


--
-- Name: feature_pub; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE feature_pub (
    feature_pub_id integer NOT NULL,
    feature_id integer NOT NULL,
    pub_id integer NOT NULL
);


--
-- Name: TABLE feature_pub; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE feature_pub IS 'Provenance. Linking table between features and publications that mention them.';


--
-- Name: feature_pub_feature_pub_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE feature_pub_feature_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: feature_pub_feature_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE feature_pub_feature_pub_id_seq OWNED BY feature_pub.feature_pub_id;


--
-- Name: feature_pubprop; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE feature_pubprop (
    feature_pubprop_id integer NOT NULL,
    feature_pub_id integer NOT NULL,
    type_id integer NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE feature_pubprop; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE feature_pubprop IS 'Property or attribute of a feature_pub link.';


--
-- Name: feature_pubprop_feature_pubprop_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE feature_pubprop_feature_pubprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: feature_pubprop_feature_pubprop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE feature_pubprop_feature_pubprop_id_seq OWNED BY feature_pubprop.feature_pubprop_id;


--
-- Name: feature_relationship; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE feature_relationship (
    feature_relationship_id integer NOT NULL,
    subject_id integer NOT NULL,
    object_id integer NOT NULL,
    type_id integer NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE feature_relationship; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE feature_relationship IS 'Features can be arranged in
graphs, e.g. "exon part_of transcript part_of gene"; If type is
thought of as a verb, the each arc or edge makes a statement
[Subject Verb Object]. The object can also be thought of as parent
(containing feature), and subject as child (contained feature or
subfeature). We include the relationship rank/order, because even
though most of the time we can order things implicitly by sequence
coordinates, we can not always do this - e.g. transpliced genes. It is also
useful for quickly getting implicit introns.';


--
-- Name: COLUMN feature_relationship.subject_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature_relationship.subject_id IS 'The subject of the subj-predicate-obj sentence. This is typically the subfeature.';


--
-- Name: COLUMN feature_relationship.object_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature_relationship.object_id IS 'The object of the subj-predicate-obj sentence. This is typically the container feature.';


--
-- Name: COLUMN feature_relationship.type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature_relationship.type_id IS 'Relationship type between subject and object. This is a cvterm, typically from the OBO relationship ontology, although other relationship types are allowed. The most common relationship type is OBO_REL:part_of. Valid relationship types are constrained by the Sequence Ontology.';


--
-- Name: COLUMN feature_relationship.value; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature_relationship.value IS 'Additional notes or comments.';


--
-- Name: COLUMN feature_relationship.rank; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature_relationship.rank IS 'The ordering of subject features with respect to the object feature may be important (for example, exon ordering on a transcript - not always derivable if you take trans spliced genes into consideration). Rank is used to order these; starts from zero.';


--
-- Name: feature_relationship_feature_relationship_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE feature_relationship_feature_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: feature_relationship_feature_relationship_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE feature_relationship_feature_relationship_id_seq OWNED BY feature_relationship.feature_relationship_id;


--
-- Name: feature_relationship_pub; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE feature_relationship_pub (
    feature_relationship_pub_id integer NOT NULL,
    feature_relationship_id integer NOT NULL,
    pub_id integer NOT NULL
);


--
-- Name: TABLE feature_relationship_pub; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE feature_relationship_pub IS 'Provenance. Attach optional evidence to a feature_relationship in the form of a publication.';


--
-- Name: feature_relationship_pub_feature_relationship_pub_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE feature_relationship_pub_feature_relationship_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: feature_relationship_pub_feature_relationship_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE feature_relationship_pub_feature_relationship_pub_id_seq OWNED BY feature_relationship_pub.feature_relationship_pub_id;


--
-- Name: feature_relationshipprop; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE feature_relationshipprop (
    feature_relationshipprop_id integer NOT NULL,
    feature_relationship_id integer NOT NULL,
    type_id integer NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE feature_relationshipprop; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE feature_relationshipprop IS 'Extensible properties
for feature_relationships. Analagous structure to featureprop. This
table is largely optional and not used with a high frequency. Typical
scenarios may be if one wishes to attach additional data to a
feature_relationship - for example to say that the
feature_relationship is only true in certain contexts.';


--
-- Name: COLUMN feature_relationshipprop.type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature_relationshipprop.type_id IS 'The name of the
property/slot is a cvterm. The meaning of the property is defined in
that cvterm. Currently there is no standard ontology for
feature_relationship property types.';


--
-- Name: COLUMN feature_relationshipprop.value; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature_relationshipprop.value IS 'The value of the
property, represented as text. Numeric values are converted to their
text representation. This is less efficient than using native database
types, but is easier to query.';


--
-- Name: COLUMN feature_relationshipprop.rank; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature_relationshipprop.rank IS 'Property-Value
ordering. Any feature_relationship can have multiple values for any particular
property type - these are ordered in a list using rank, counting from
zero. For properties that are single-valued rather than multi-valued,
the default 0 value should be used.';


--
-- Name: feature_relationshipprop_feature_relationshipprop_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE feature_relationshipprop_feature_relationshipprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: feature_relationshipprop_feature_relationshipprop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE feature_relationshipprop_feature_relationshipprop_id_seq OWNED BY feature_relationshipprop.feature_relationshipprop_id;


--
-- Name: feature_relationshipprop_pub; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE feature_relationshipprop_pub (
    feature_relationshipprop_pub_id integer NOT NULL,
    feature_relationshipprop_id integer NOT NULL,
    pub_id integer NOT NULL
);


--
-- Name: TABLE feature_relationshipprop_pub; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE feature_relationshipprop_pub IS 'Provenance for feature_relationshipprop.';


--
-- Name: feature_relationshipprop_pub_feature_relationshipprop_pub_i_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE feature_relationshipprop_pub_feature_relationshipprop_pub_i_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: feature_relationshipprop_pub_feature_relationshipprop_pub_i_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE feature_relationshipprop_pub_feature_relationshipprop_pub_i_seq OWNED BY feature_relationshipprop_pub.feature_relationshipprop_pub_id;


--
-- Name: feature_synonym; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE feature_synonym (
    feature_synonym_id integer NOT NULL,
    synonym_id integer NOT NULL,
    feature_id integer NOT NULL,
    pub_id integer NOT NULL,
    is_current boolean DEFAULT false NOT NULL,
    is_internal boolean DEFAULT false NOT NULL
);


--
-- Name: TABLE feature_synonym; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE feature_synonym IS 'Linking table between feature and synonym.';


--
-- Name: COLUMN feature_synonym.pub_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature_synonym.pub_id IS 'The pub_id link is for relating the usage of a given synonym to the publication in which it was used.';


--
-- Name: COLUMN feature_synonym.is_current; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature_synonym.is_current IS 'The is_current boolean indicates whether the linked synonym is the  current -official- symbol for the linked feature.';


--
-- Name: COLUMN feature_synonym.is_internal; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN feature_synonym.is_internal IS 'Typically a synonym exists so that somebody querying the db with an obsolete name can find the object theyre looking for (under its current name.  If the synonym has been used publicly and deliberately (e.g. in a paper), it may also be listed in reports as a synonym. If the synonym was not used deliberately (e.g. there was a typo which went public), then the is_internal boolean may be set to -true- so that it is known that the synonym is -internal- and should be queryable but should not be listed in reports as a valid synonym.';


--
-- Name: feature_synonym_feature_synonym_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE feature_synonym_feature_synonym_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: feature_synonym_feature_synonym_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE feature_synonym_feature_synonym_id_seq OWNED BY feature_synonym.feature_synonym_id;


--
-- Name: feature_uniquename_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE feature_uniquename_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: featureloc; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE featureloc (
    featureloc_id integer NOT NULL,
    feature_id integer NOT NULL,
    srcfeature_id integer,
    fmin integer,
    is_fmin_partial boolean DEFAULT false NOT NULL,
    fmax integer,
    is_fmax_partial boolean DEFAULT false NOT NULL,
    strand smallint,
    phase integer,
    residue_info text,
    locgroup integer DEFAULT 0 NOT NULL,
    rank integer DEFAULT 0 NOT NULL,
    CONSTRAINT featureloc_c2 CHECK ((fmin <= fmax))
);


--
-- Name: TABLE featureloc; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE featureloc IS 'The location of a feature relative to
another feature. Important: interbase coordinates are used. This is
vital as it allows us to represent zero-length features e.g. splice
sites, insertion points without an awkward fuzzy system. Features
typically have exactly ONE location, but this need not be the
case. Some features may not be localized (e.g. a gene that has been
characterized genetically but no sequence or molecular information is
available). Note on multiple locations: Each feature can have 0 or
more locations. Multiple locations do NOT indicate non-contiguous
locations (if a feature such as a transcript has a non-contiguous
location, then the subfeatures such as exons should always be
manifested). Instead, multiple featurelocs for a feature designate
alternate locations or grouped locations; for instance, a feature
designating a blast hit or hsp will have two locations, one on the
query feature, one on the subject feature. Features representing
sequence variation could have alternate locations instantiated on a
feature on the mutant strain. The column:rank is used to
differentiate these different locations. Reflexive locations should
never be stored - this is for -proper- (i.e. non-self) locations only; nothing should be located relative to itself.';


--
-- Name: COLUMN featureloc.feature_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN featureloc.feature_id IS 'The feature that is being located. Any feature can have zero or more featurelocs.';


--
-- Name: COLUMN featureloc.srcfeature_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN featureloc.srcfeature_id IS 'The source feature which this location is relative to. Every location is relative to another feature (however, this column is nullable, because the srcfeature may not be known). All locations are -proper- that is, nothing should be located relative to itself. No cycles are allowed in the featureloc graph.';


--
-- Name: COLUMN featureloc.fmin; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN featureloc.fmin IS 'The leftmost/minimal boundary in the linear range represented by the featureloc. Sometimes (e.g. in Bioperl) this is called -start- although this is confusing because it does not necessarily represent the 5-prime coordinate. Important: This is space-based (interbase) coordinates, counting from zero. To convert this to the leftmost position in a base-oriented system (eg GFF, Bioperl), add 1 to fmin.';


--
-- Name: COLUMN featureloc.is_fmin_partial; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN featureloc.is_fmin_partial IS 'This is typically
false, but may be true if the value for column:fmin is inaccurate or
the leftmost part of the range is unknown/unbounded.';


--
-- Name: COLUMN featureloc.fmax; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN featureloc.fmax IS 'The rightmost/maximal boundary in the linear range represented by the featureloc. Sometimes (e.g. in bioperl) this is called -end- although this is confusing because it does not necessarily represent the 3-prime coordinate. Important: This is space-based (interbase) coordinates, counting from zero. No conversion is required to go from fmax to the rightmost coordinate in a base-oriented system that counts from 1 (e.g. GFF, Bioperl).';


--
-- Name: COLUMN featureloc.is_fmax_partial; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN featureloc.is_fmax_partial IS 'This is typically
false, but may be true if the value for column:fmax is inaccurate or
the rightmost part of the range is unknown/unbounded.';


--
-- Name: COLUMN featureloc.strand; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN featureloc.strand IS 'The orientation/directionality of the
location. Should be 0, -1 or +1.';


--
-- Name: COLUMN featureloc.phase; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN featureloc.phase IS 'Phase of translation with
respect to srcfeature_id.
Values are 0, 1, 2. It may not be possible to manifest this column for
some features such as exons, because the phase is dependant on the
spliceform (the same exon can appear in multiple spliceforms). This column is mostly useful for predicted exons and CDSs.';


--
-- Name: COLUMN featureloc.residue_info; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN featureloc.residue_info IS 'Alternative residues,
when these differ from feature.residues. For instance, a SNP feature
located on a wild and mutant protein would have different alternative residues.
for alignment/similarity features, the alternative residues is used to
represent the alignment string (CIGAR format). Note on variation
features; even if we do not want to instantiate a mutant
chromosome/contig feature, we can still represent a SNP etc with 2
locations, one (rank 0) on the genome, the other (rank 1) would have
most fields null, except for alternative residues.';


--
-- Name: COLUMN featureloc.locgroup; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN featureloc.locgroup IS 'This is used to manifest redundant,
derivable extra locations for a feature. The default locgroup=0 is
used for the DIRECT location of a feature. Important: most Chado users may
never use featurelocs WITH logroup > 0. Transitively derived locations
are indicated with locgroup > 0. For example, the position of an exon on
a BAC and in global chromosome coordinates. This column is used to
differentiate these groupings of locations. The default locgroup 0
is used for the main or primary location, from which the others can be
derived via coordinate transformations. Another example of redundant
locations is storing ORF coordinates relative to both transcript and
genome. Redundant locations open the possibility of the database
getting into inconsistent states; this schema gives us the flexibility
of both warehouse instantiations with redundant locations (easier for
querying) and management instantiations with no redundant
locations. An example of using both locgroup and rank: imagine a
feature indicating a conserved region between the chromosomes of two
different species. We may want to keep redundant locations on both
contigs and chromosomes. We would thus have 4 locations for the single
conserved region feature - two distinct locgroups (contig level and
chromosome level) and two distinct ranks (for the two species).';


--
-- Name: COLUMN featureloc.rank; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN featureloc.rank IS 'Used when a feature has >1
location, otherwise the default rank 0 is used. Some features (e.g.
blast hits and HSPs) have two locations - one on the query and one on
the subject. Rank is used to differentiate these. Rank=0 is always
used for the query, Rank=1 for the subject. For multiple alignments,
assignment of rank is arbitrary. Rank is also used for
sequence_variant features, such as SNPs. Rank=0 indicates the wildtype
(or baseline) feature, Rank=1 indicates the mutant (or compared) feature.';


--
-- Name: featureloc_featureloc_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE featureloc_featureloc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: featureloc_featureloc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE featureloc_featureloc_id_seq OWNED BY featureloc.featureloc_id;


--
-- Name: featureloc_pub; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE featureloc_pub (
    featureloc_pub_id integer NOT NULL,
    featureloc_id integer NOT NULL,
    pub_id integer NOT NULL
);


--
-- Name: TABLE featureloc_pub; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE featureloc_pub IS 'Provenance of featureloc. Linking table between featurelocs and publications that mention them.';


--
-- Name: featureloc_pub_featureloc_pub_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE featureloc_pub_featureloc_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: featureloc_pub_featureloc_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE featureloc_pub_featureloc_pub_id_seq OWNED BY featureloc_pub.featureloc_pub_id;


--
-- Name: featureprop; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE featureprop (
    featureprop_id integer NOT NULL,
    feature_id integer NOT NULL,
    type_id integer NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE featureprop; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE featureprop IS 'A feature can have any number of slot-value property tags attached to it. This is an alternative to hardcoding a list of columns in the relational schema, and is completely extensible.';


--
-- Name: COLUMN featureprop.type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN featureprop.type_id IS 'The name of the
property/slot is a cvterm. The meaning of the property is defined in
that cvterm. Certain property types will only apply to certain feature
types (e.g. the anticodon property will only apply to tRNA features) ;
the types here come from the sequence feature property ontology.';


--
-- Name: COLUMN featureprop.value; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN featureprop.value IS 'The value of the property, represented as text. Numeric values are converted to their text representation. This is less efficient than using native database types, but is easier to query.';


--
-- Name: COLUMN featureprop.rank; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN featureprop.rank IS 'Property-Value ordering. Any
feature can have multiple values for any particular property type -
these are ordered in a list using rank, counting from zero. For
properties that are single-valued rather than multi-valued, the
default 0 value should be used';


--
-- Name: featureprop_featureprop_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE featureprop_featureprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: featureprop_featureprop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE featureprop_featureprop_id_seq OWNED BY featureprop.featureprop_id;


--
-- Name: featureprop_pub; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE featureprop_pub (
    featureprop_pub_id integer NOT NULL,
    featureprop_id integer NOT NULL,
    pub_id integer NOT NULL
);


--
-- Name: TABLE featureprop_pub; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE featureprop_pub IS 'Provenance. Any featureprop assignment can optionally be supported by a publication.';


--
-- Name: featureprop_pub_featureprop_pub_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE featureprop_pub_featureprop_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: featureprop_pub_featureprop_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE featureprop_pub_featureprop_pub_id_seq OWNED BY featureprop_pub.featureprop_pub_id;


--
-- Name: genotype; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE genotype (
    genotype_id integer NOT NULL,
    name text,
    uniquename text NOT NULL,
    description character varying(255),
    type_id integer NOT NULL
);


--
-- Name: TABLE genotype; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE genotype IS 'Genetic context. A genotype is defined by a collection of features, mutations, balancers, deficiencies, haplotype blocks, or engineered constructs.';


--
-- Name: COLUMN genotype.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN genotype.name IS 'Optional alternative name for a genotype, 
for display purposes.';


--
-- Name: COLUMN genotype.uniquename; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN genotype.uniquename IS 'The unique name for a genotype; 
typically derived from the features making up the genotype.';


--
-- Name: genotype_genotype_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE genotype_genotype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: genotype_genotype_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE genotype_genotype_id_seq OWNED BY genotype.genotype_id;


--
-- Name: genotypeprop; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE genotypeprop (
    genotypeprop_id integer NOT NULL,
    genotype_id integer NOT NULL,
    type_id integer NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: genotypeprop_genotypeprop_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE genotypeprop_genotypeprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: genotypeprop_genotypeprop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE genotypeprop_genotypeprop_id_seq OWNED BY genotypeprop.genotypeprop_id;


--
-- Name: nd_experiment; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE nd_experiment (
    nd_experiment_id integer NOT NULL,
    nd_geolocation_id integer NOT NULL,
    type_id integer NOT NULL
);


--
-- Name: nd_experiment_contact; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE nd_experiment_contact (
    nd_experiment_contact_id integer NOT NULL,
    nd_experiment_id integer NOT NULL,
    contact_id integer NOT NULL
);


--
-- Name: nd_experiment_contact_nd_experiment_contact_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE nd_experiment_contact_nd_experiment_contact_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: nd_experiment_contact_nd_experiment_contact_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE nd_experiment_contact_nd_experiment_contact_id_seq OWNED BY nd_experiment_contact.nd_experiment_contact_id;


--
-- Name: nd_experiment_dbxref; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE nd_experiment_dbxref (
    nd_experiment_dbxref_id integer NOT NULL,
    nd_experiment_id integer NOT NULL,
    dbxref_id integer NOT NULL
);


--
-- Name: TABLE nd_experiment_dbxref; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE nd_experiment_dbxref IS 'Cross-reference experiment to accessions, images, etc';


--
-- Name: nd_experiment_dbxref_nd_experiment_dbxref_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE nd_experiment_dbxref_nd_experiment_dbxref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: nd_experiment_dbxref_nd_experiment_dbxref_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE nd_experiment_dbxref_nd_experiment_dbxref_id_seq OWNED BY nd_experiment_dbxref.nd_experiment_dbxref_id;


--
-- Name: nd_experiment_genotype; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE nd_experiment_genotype (
    nd_experiment_genotype_id integer NOT NULL,
    nd_experiment_id integer NOT NULL,
    genotype_id integer NOT NULL
);


--
-- Name: TABLE nd_experiment_genotype; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE nd_experiment_genotype IS 'Linking table: experiments to the genotypes they produce. There is a one-to-one relationship between an experiment and a genotype since each genotype record should point to one experiment. Add a new experiment_id for each genotype record.';


--
-- Name: nd_experiment_genotype_nd_experiment_genotype_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE nd_experiment_genotype_nd_experiment_genotype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: nd_experiment_genotype_nd_experiment_genotype_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE nd_experiment_genotype_nd_experiment_genotype_id_seq OWNED BY nd_experiment_genotype.nd_experiment_genotype_id;


--
-- Name: nd_experiment_nd_experiment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE nd_experiment_nd_experiment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: nd_experiment_nd_experiment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE nd_experiment_nd_experiment_id_seq OWNED BY nd_experiment.nd_experiment_id;


--
-- Name: nd_experiment_phenotype; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE nd_experiment_phenotype (
    nd_experiment_phenotype_id integer NOT NULL,
    nd_experiment_id integer NOT NULL,
    phenotype_id integer NOT NULL
);


--
-- Name: TABLE nd_experiment_phenotype; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE nd_experiment_phenotype IS 'Linking table: experiments to the phenotypes they produce. There is a one-to-one relationship between an experiment and a phenotype since each phenotype record should point to one experiment. Add a new experiment_id for each phenotype record.';


--
-- Name: nd_experiment_phenotype_nd_experiment_phenotype_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE nd_experiment_phenotype_nd_experiment_phenotype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: nd_experiment_phenotype_nd_experiment_phenotype_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE nd_experiment_phenotype_nd_experiment_phenotype_id_seq OWNED BY nd_experiment_phenotype.nd_experiment_phenotype_id;


--
-- Name: nd_experiment_project; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE nd_experiment_project (
    nd_experiment_project_id integer NOT NULL,
    project_id integer NOT NULL,
    nd_experiment_id integer NOT NULL
);


--
-- Name: nd_experiment_project_nd_experiment_project_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE nd_experiment_project_nd_experiment_project_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: nd_experiment_project_nd_experiment_project_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE nd_experiment_project_nd_experiment_project_id_seq OWNED BY nd_experiment_project.nd_experiment_project_id;


--
-- Name: nd_experiment_protocol; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE nd_experiment_protocol (
    nd_experiment_protocol_id integer NOT NULL,
    nd_experiment_id integer NOT NULL,
    nd_protocol_id integer NOT NULL
);


--
-- Name: TABLE nd_experiment_protocol; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE nd_experiment_protocol IS 'Linking table: experiments to the protocols they involve.';


--
-- Name: nd_experiment_protocol_nd_experiment_protocol_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE nd_experiment_protocol_nd_experiment_protocol_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: nd_experiment_protocol_nd_experiment_protocol_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE nd_experiment_protocol_nd_experiment_protocol_id_seq OWNED BY nd_experiment_protocol.nd_experiment_protocol_id;


--
-- Name: nd_experiment_pub; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE nd_experiment_pub (
    nd_experiment_pub_id integer NOT NULL,
    nd_experiment_id integer NOT NULL,
    pub_id integer NOT NULL
);


--
-- Name: TABLE nd_experiment_pub; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE nd_experiment_pub IS 'Linking nd_experiment(s) to publication(s)';


--
-- Name: nd_experiment_pub_nd_experiment_pub_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE nd_experiment_pub_nd_experiment_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: nd_experiment_pub_nd_experiment_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE nd_experiment_pub_nd_experiment_pub_id_seq OWNED BY nd_experiment_pub.nd_experiment_pub_id;


--
-- Name: nd_experiment_stock; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE nd_experiment_stock (
    nd_experiment_stock_id integer NOT NULL,
    nd_experiment_id integer NOT NULL,
    stock_id integer NOT NULL,
    type_id integer NOT NULL
);


--
-- Name: TABLE nd_experiment_stock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE nd_experiment_stock IS 'Part of a stock or a clone of a stock that is used in an experiment';


--
-- Name: COLUMN nd_experiment_stock.stock_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN nd_experiment_stock.stock_id IS 'stock used in the extraction or the corresponding stock for the clone';


--
-- Name: nd_experiment_stock_dbxref; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE nd_experiment_stock_dbxref (
    nd_experiment_stock_dbxref_id integer NOT NULL,
    nd_experiment_stock_id integer NOT NULL,
    dbxref_id integer NOT NULL
);


--
-- Name: TABLE nd_experiment_stock_dbxref; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE nd_experiment_stock_dbxref IS 'Cross-reference experiment_stock to accessions, images, etc';


--
-- Name: nd_experiment_stock_dbxref_nd_experiment_stock_dbxref_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE nd_experiment_stock_dbxref_nd_experiment_stock_dbxref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: nd_experiment_stock_dbxref_nd_experiment_stock_dbxref_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE nd_experiment_stock_dbxref_nd_experiment_stock_dbxref_id_seq OWNED BY nd_experiment_stock_dbxref.nd_experiment_stock_dbxref_id;


--
-- Name: nd_experiment_stock_nd_experiment_stock_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE nd_experiment_stock_nd_experiment_stock_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: nd_experiment_stock_nd_experiment_stock_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE nd_experiment_stock_nd_experiment_stock_id_seq OWNED BY nd_experiment_stock.nd_experiment_stock_id;


--
-- Name: nd_experiment_stockprop; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE nd_experiment_stockprop (
    nd_experiment_stockprop_id integer NOT NULL,
    nd_experiment_stock_id integer NOT NULL,
    type_id integer NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE nd_experiment_stockprop; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE nd_experiment_stockprop IS 'Property/value associations for experiment_stocks. This table can store the properties such as treatment';


--
-- Name: COLUMN nd_experiment_stockprop.nd_experiment_stock_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN nd_experiment_stockprop.nd_experiment_stock_id IS 'The experiment_stock to which the property applies.';


--
-- Name: COLUMN nd_experiment_stockprop.type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN nd_experiment_stockprop.type_id IS 'The name of the property as a reference to a controlled vocabulary term.';


--
-- Name: COLUMN nd_experiment_stockprop.value; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN nd_experiment_stockprop.value IS 'The value of the property.';


--
-- Name: COLUMN nd_experiment_stockprop.rank; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN nd_experiment_stockprop.rank IS 'The rank of the property value, if the property has an array of values.';


--
-- Name: nd_experiment_stockprop_nd_experiment_stockprop_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE nd_experiment_stockprop_nd_experiment_stockprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: nd_experiment_stockprop_nd_experiment_stockprop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE nd_experiment_stockprop_nd_experiment_stockprop_id_seq OWNED BY nd_experiment_stockprop.nd_experiment_stockprop_id;


--
-- Name: nd_experimentprop; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE nd_experimentprop (
    nd_experimentprop_id integer NOT NULL,
    nd_experiment_id integer NOT NULL,
    type_id integer NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: nd_experimentprop_nd_experimentprop_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE nd_experimentprop_nd_experimentprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: nd_experimentprop_nd_experimentprop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE nd_experimentprop_nd_experimentprop_id_seq OWNED BY nd_experimentprop.nd_experimentprop_id;


--
-- Name: nd_geolocation; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE nd_geolocation (
    nd_geolocation_id integer NOT NULL,
    description character varying(255),
    latitude real,
    longitude real,
    geodetic_datum character varying(32),
    altitude real
);


--
-- Name: TABLE nd_geolocation; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE nd_geolocation IS 'The geo-referencable location of the stock. NOTE: This entity is subject to change as a more general and possibly more OpenGIS-compliant geolocation module may be introduced into Chado.';


--
-- Name: COLUMN nd_geolocation.description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN nd_geolocation.description IS 'A textual representation of the location, if this is the original georeference. Optional if the original georeference is available in lat/long coordinates.';


--
-- Name: COLUMN nd_geolocation.latitude; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN nd_geolocation.latitude IS 'The decimal latitude coordinate of the georeference, using positive and negative sign to indicate N and S, respectively.';


--
-- Name: COLUMN nd_geolocation.longitude; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN nd_geolocation.longitude IS 'The decimal longitude coordinate of the georeference, using positive and negative sign to indicate E and W, respectively.';


--
-- Name: COLUMN nd_geolocation.geodetic_datum; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN nd_geolocation.geodetic_datum IS 'The geodetic system on which the geo-reference coordinates are based. For geo-references measured between 1984 and 2010, this will typically be WGS84.';


--
-- Name: COLUMN nd_geolocation.altitude; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN nd_geolocation.altitude IS 'The altitude (elevation) of the location in meters. If the altitude is only known as a range, this is the average, and altitude_dev will hold half of the width of the range.';


--
-- Name: nd_geolocation_nd_geolocation_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE nd_geolocation_nd_geolocation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: nd_geolocation_nd_geolocation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE nd_geolocation_nd_geolocation_id_seq OWNED BY nd_geolocation.nd_geolocation_id;


--
-- Name: nd_geolocationprop; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE nd_geolocationprop (
    nd_geolocationprop_id integer NOT NULL,
    nd_geolocation_id integer NOT NULL,
    type_id integer NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE nd_geolocationprop; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE nd_geolocationprop IS 'Property/value associations for geolocations. This table can store the properties such as location and environment';


--
-- Name: COLUMN nd_geolocationprop.type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN nd_geolocationprop.type_id IS 'The name of the property as a reference to a controlled vocabulary term.';


--
-- Name: COLUMN nd_geolocationprop.value; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN nd_geolocationprop.value IS 'The value of the property.';


--
-- Name: COLUMN nd_geolocationprop.rank; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN nd_geolocationprop.rank IS 'The rank of the property value, if the property has an array of values.';


--
-- Name: nd_geolocationprop_nd_geolocationprop_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE nd_geolocationprop_nd_geolocationprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: nd_geolocationprop_nd_geolocationprop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE nd_geolocationprop_nd_geolocationprop_id_seq OWNED BY nd_geolocationprop.nd_geolocationprop_id;


--
-- Name: nd_protocol; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE nd_protocol (
    nd_protocol_id integer NOT NULL,
    name character varying(255) NOT NULL,
    type_id integer NOT NULL
);


--
-- Name: TABLE nd_protocol; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE nd_protocol IS 'A protocol can be anything that is done as part of the experiment.';


--
-- Name: COLUMN nd_protocol.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN nd_protocol.name IS 'The protocol name.';


--
-- Name: nd_protocol_nd_protocol_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE nd_protocol_nd_protocol_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: nd_protocol_nd_protocol_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE nd_protocol_nd_protocol_id_seq OWNED BY nd_protocol.nd_protocol_id;


--
-- Name: nd_protocol_reagent; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE nd_protocol_reagent (
    nd_protocol_reagent_id integer NOT NULL,
    nd_protocol_id integer NOT NULL,
    reagent_id integer NOT NULL,
    type_id integer NOT NULL
);


--
-- Name: nd_protocol_reagent_nd_protocol_reagent_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE nd_protocol_reagent_nd_protocol_reagent_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: nd_protocol_reagent_nd_protocol_reagent_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE nd_protocol_reagent_nd_protocol_reagent_id_seq OWNED BY nd_protocol_reagent.nd_protocol_reagent_id;


--
-- Name: nd_protocolprop; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE nd_protocolprop (
    nd_protocolprop_id integer NOT NULL,
    nd_protocol_id integer NOT NULL,
    type_id integer NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE nd_protocolprop; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE nd_protocolprop IS 'Property/value associations for protocol.';


--
-- Name: COLUMN nd_protocolprop.nd_protocol_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN nd_protocolprop.nd_protocol_id IS 'The protocol to which the property applies.';


--
-- Name: COLUMN nd_protocolprop.type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN nd_protocolprop.type_id IS 'The name of the property as a reference to a controlled vocabulary term.';


--
-- Name: COLUMN nd_protocolprop.value; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN nd_protocolprop.value IS 'The value of the property.';


--
-- Name: COLUMN nd_protocolprop.rank; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN nd_protocolprop.rank IS 'The rank of the property value, if the property has an array of values.';


--
-- Name: nd_protocolprop_nd_protocolprop_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE nd_protocolprop_nd_protocolprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: nd_protocolprop_nd_protocolprop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE nd_protocolprop_nd_protocolprop_id_seq OWNED BY nd_protocolprop.nd_protocolprop_id;


--
-- Name: nd_reagent; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE nd_reagent (
    nd_reagent_id integer NOT NULL,
    name character varying(80) NOT NULL,
    type_id integer NOT NULL,
    feature_id integer
);


--
-- Name: TABLE nd_reagent; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE nd_reagent IS 'A reagent such as a primer, an enzyme, an adapter oligo, a linker oligo. Reagents are used in genotyping experiments, or in any other kind of experiment.';


--
-- Name: COLUMN nd_reagent.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN nd_reagent.name IS 'The name of the reagent. The name should be unique for a given type.';


--
-- Name: COLUMN nd_reagent.type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN nd_reagent.type_id IS 'The type of the reagent, for example linker oligomer, or forward primer.';


--
-- Name: COLUMN nd_reagent.feature_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN nd_reagent.feature_id IS 'If the reagent is a primer, the feature that it corresponds to. More generally, the corresponding feature for any reagent that has a sequence that maps to another sequence.';


--
-- Name: nd_reagent_nd_reagent_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE nd_reagent_nd_reagent_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: nd_reagent_nd_reagent_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE nd_reagent_nd_reagent_id_seq OWNED BY nd_reagent.nd_reagent_id;


--
-- Name: nd_reagent_relationship; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE nd_reagent_relationship (
    nd_reagent_relationship_id integer NOT NULL,
    subject_reagent_id integer NOT NULL,
    object_reagent_id integer NOT NULL,
    type_id integer NOT NULL
);


--
-- Name: TABLE nd_reagent_relationship; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE nd_reagent_relationship IS 'Relationships between reagents. Some reagents form a group. i.e., they are used all together or not at all. Examples are adapter/linker/enzyme experiment reagents.';


--
-- Name: COLUMN nd_reagent_relationship.subject_reagent_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN nd_reagent_relationship.subject_reagent_id IS 'The subject reagent in the relationship. In parent/child terminology, the subject is the child. For example, in "linkerA 3prime-overhang-linker enzymeA" linkerA is the subject, 3prime-overhand-linker is the type, and enzymeA is the object.';


--
-- Name: COLUMN nd_reagent_relationship.object_reagent_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN nd_reagent_relationship.object_reagent_id IS 'The object reagent in the relationship. In parent/child terminology, the object is the parent. For example, in "linkerA 3prime-overhang-linker enzymeA" linkerA is the subject, 3prime-overhand-linker is the type, and enzymeA is the object.';


--
-- Name: COLUMN nd_reagent_relationship.type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN nd_reagent_relationship.type_id IS 'The type (or predicate) of the relationship. For example, in "linkerA 3prime-overhang-linker enzymeA" linkerA is the subject, 3prime-overhand-linker is the type, and enzymeA is the object.';


--
-- Name: nd_reagent_relationship_nd_reagent_relationship_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE nd_reagent_relationship_nd_reagent_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: nd_reagent_relationship_nd_reagent_relationship_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE nd_reagent_relationship_nd_reagent_relationship_id_seq OWNED BY nd_reagent_relationship.nd_reagent_relationship_id;


--
-- Name: nd_reagentprop; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE nd_reagentprop (
    nd_reagentprop_id integer NOT NULL,
    nd_reagent_id integer NOT NULL,
    type_id integer NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: nd_reagentprop_nd_reagentprop_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE nd_reagentprop_nd_reagentprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: nd_reagentprop_nd_reagentprop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE nd_reagentprop_nd_reagentprop_id_seq OWNED BY nd_reagentprop.nd_reagentprop_id;


--
-- Name: organism; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE organism (
    organism_id integer NOT NULL,
    abbreviation character varying(255),
    genus character varying(255) NOT NULL,
    species character varying(255) NOT NULL,
    common_name character varying(255),
    comment text
);


--
-- Name: TABLE organism; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE organism IS 'The organismal taxonomic
classification. Note that phylogenies are represented using the
phylogeny module, and taxonomies can be represented using the cvterm
module or the phylogeny module.';


--
-- Name: COLUMN organism.species; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN organism.species IS 'A type of organism is always
uniquely identified by genus and species. When mapping from the NCBI
taxonomy names.dmp file, this column must be used where it
is present, as the common_name column is not always unique (e.g. environmental
samples). If a particular strain or subspecies is to be represented,
this is appended onto the species name. Follows standard NCBI taxonomy
pattern.';


--
-- Name: organism_dbxref; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE organism_dbxref (
    organism_dbxref_id integer NOT NULL,
    organism_id integer NOT NULL,
    dbxref_id integer NOT NULL
);


--
-- Name: organism_dbxref_organism_dbxref_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE organism_dbxref_organism_dbxref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: organism_dbxref_organism_dbxref_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE organism_dbxref_organism_dbxref_id_seq OWNED BY organism_dbxref.organism_dbxref_id;


--
-- Name: organism_organism_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE organism_organism_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: organism_organism_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE organism_organism_id_seq OWNED BY organism.organism_id;


--
-- Name: organismprop; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE organismprop (
    organismprop_id integer NOT NULL,
    organism_id integer NOT NULL,
    type_id integer NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE organismprop; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE organismprop IS 'Tag-value properties - follows standard chado model.';


--
-- Name: organismprop_organismprop_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE organismprop_organismprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: organismprop_organismprop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE organismprop_organismprop_id_seq OWNED BY organismprop.organismprop_id;


--
-- Name: phendesc; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE phendesc (
    phendesc_id integer NOT NULL,
    genotype_id integer NOT NULL,
    environment_id integer NOT NULL,
    description text NOT NULL,
    type_id integer NOT NULL,
    pub_id integer NOT NULL
);


--
-- Name: TABLE phendesc; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE phendesc IS 'A summary of a _set_ of phenotypic statements for any one gcontext made in any one publication.';


--
-- Name: phendesc_phendesc_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE phendesc_phendesc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: phendesc_phendesc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE phendesc_phendesc_id_seq OWNED BY phendesc.phendesc_id;


--
-- Name: phenotype; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE phenotype (
    phenotype_id integer NOT NULL,
    uniquename text NOT NULL,
    name text,
    observable_id integer,
    attr_id integer,
    value text,
    cvalue_id integer,
    assay_id integer
);


--
-- Name: TABLE phenotype; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE phenotype IS 'A phenotypic statement, or a single
atomic phenotypic observation, is a controlled sentence describing
observable effects of non-wild type function. E.g. Obs=eye, attribute=color, cvalue=red.';


--
-- Name: COLUMN phenotype.observable_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN phenotype.observable_id IS 'The entity: e.g. anatomy_part, biological_process.';


--
-- Name: COLUMN phenotype.attr_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN phenotype.attr_id IS 'Phenotypic attribute (quality, property, attribute, character) - drawn from PATO.';


--
-- Name: COLUMN phenotype.value; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN phenotype.value IS 'Value of attribute - unconstrained free text. Used only if cvalue_id is not appropriate.';


--
-- Name: COLUMN phenotype.cvalue_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN phenotype.cvalue_id IS 'Phenotype attribute value (state).';


--
-- Name: COLUMN phenotype.assay_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN phenotype.assay_id IS 'Evidence type.';


--
-- Name: phenotype_comparison; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE phenotype_comparison (
    phenotype_comparison_id integer NOT NULL,
    genotype1_id integer NOT NULL,
    environment1_id integer NOT NULL,
    genotype2_id integer NOT NULL,
    environment2_id integer NOT NULL,
    phenotype1_id integer NOT NULL,
    phenotype2_id integer,
    pub_id integer NOT NULL,
    organism_id integer NOT NULL
);


--
-- Name: TABLE phenotype_comparison; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE phenotype_comparison IS 'Comparison of phenotypes e.g., genotype1/environment1/phenotype1 "non-suppressible" with respect to genotype2/environment2/phenotype2.';


--
-- Name: phenotype_comparison_cvterm; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE phenotype_comparison_cvterm (
    phenotype_comparison_cvterm_id integer NOT NULL,
    phenotype_comparison_id integer NOT NULL,
    cvterm_id integer NOT NULL,
    pub_id integer NOT NULL,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: phenotype_comparison_cvterm_phenotype_comparison_cvterm_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE phenotype_comparison_cvterm_phenotype_comparison_cvterm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: phenotype_comparison_cvterm_phenotype_comparison_cvterm_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE phenotype_comparison_cvterm_phenotype_comparison_cvterm_id_seq OWNED BY phenotype_comparison_cvterm.phenotype_comparison_cvterm_id;


--
-- Name: phenotype_comparison_phenotype_comparison_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE phenotype_comparison_phenotype_comparison_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: phenotype_comparison_phenotype_comparison_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE phenotype_comparison_phenotype_comparison_id_seq OWNED BY phenotype_comparison.phenotype_comparison_id;


--
-- Name: phenotype_cvterm; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE phenotype_cvterm (
    phenotype_cvterm_id integer NOT NULL,
    phenotype_id integer NOT NULL,
    cvterm_id integer NOT NULL,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: phenotype_cvterm_phenotype_cvterm_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE phenotype_cvterm_phenotype_cvterm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: phenotype_cvterm_phenotype_cvterm_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE phenotype_cvterm_phenotype_cvterm_id_seq OWNED BY phenotype_cvterm.phenotype_cvterm_id;


--
-- Name: phenotype_phenotype_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE phenotype_phenotype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: phenotype_phenotype_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE phenotype_phenotype_id_seq OWNED BY phenotype.phenotype_id;


--
-- Name: phenotypeprop; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE phenotypeprop (
    phenotypeprop_id integer NOT NULL,
    phenotype_id integer NOT NULL,
    type_id integer NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE phenotypeprop; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE phenotypeprop IS 'A phenotype can have any number of
slot-value property tags attached to it. This is an alternative to
hardcoding a list of columns in the relational schema, and is
completely extensible. There is a unique constraint, phenotypeprop_c1, for
the combination of phenotype_id, rank, and type_id. Multivalued property-value pairs must be differentiated by rank.';


--
-- Name: phenotypeprop_phenotypeprop_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE phenotypeprop_phenotypeprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: phenotypeprop_phenotypeprop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE phenotypeprop_phenotypeprop_id_seq OWNED BY phenotypeprop.phenotypeprop_id;


--
-- Name: phenstatement; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE phenstatement (
    phenstatement_id integer NOT NULL,
    genotype_id integer NOT NULL,
    environment_id integer NOT NULL,
    phenotype_id integer NOT NULL,
    type_id integer NOT NULL,
    pub_id integer NOT NULL
);


--
-- Name: TABLE phenstatement; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE phenstatement IS 'Phenotypes are things like "larval lethal".  Phenstatements are things like "dpp-1 is recessive larval lethal". So essentially phenstatement is a linking table expressing the relationship between genotype, environment, and phenotype.';


--
-- Name: phenstatement_phenstatement_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE phenstatement_phenstatement_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: phenstatement_phenstatement_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE phenstatement_phenstatement_id_seq OWNED BY phenstatement.phenstatement_id;


--
-- Name: project; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE project (
    project_id integer NOT NULL,
    name character varying(255) NOT NULL,
    description character varying(4096) NOT NULL
);


--
-- Name: project_contact; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE project_contact (
    project_contact_id integer NOT NULL,
    project_id integer NOT NULL,
    contact_id integer NOT NULL
);


--
-- Name: TABLE project_contact; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE project_contact IS 'Linking project(s) to contact(s)';


--
-- Name: project_contact_project_contact_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE project_contact_project_contact_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: project_contact_project_contact_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE project_contact_project_contact_id_seq OWNED BY project_contact.project_contact_id;


--
-- Name: project_project_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE project_project_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: project_project_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE project_project_id_seq OWNED BY project.project_id;


--
-- Name: project_pub; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE project_pub (
    project_pub_id integer NOT NULL,
    project_id integer NOT NULL,
    pub_id integer NOT NULL
);


--
-- Name: TABLE project_pub; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE project_pub IS 'Linking project(s) to publication(s)';


--
-- Name: project_pub_project_pub_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE project_pub_project_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: project_pub_project_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE project_pub_project_pub_id_seq OWNED BY project_pub.project_pub_id;


--
-- Name: project_relationship; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE project_relationship (
    project_relationship_id integer NOT NULL,
    subject_project_id integer NOT NULL,
    object_project_id integer NOT NULL,
    type_id integer NOT NULL
);


--
-- Name: TABLE project_relationship; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE project_relationship IS 'A project can be composed of several smaller scale projects';


--
-- Name: COLUMN project_relationship.type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN project_relationship.type_id IS 'The type of relationship being stated, such as "is part of".';


--
-- Name: project_relationship_project_relationship_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE project_relationship_project_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: project_relationship_project_relationship_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE project_relationship_project_relationship_id_seq OWNED BY project_relationship.project_relationship_id;


--
-- Name: projectprop; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE projectprop (
    projectprop_id integer NOT NULL,
    project_id integer NOT NULL,
    type_id integer NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: projectprop_projectprop_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE projectprop_projectprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: projectprop_projectprop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE projectprop_projectprop_id_seq OWNED BY projectprop.projectprop_id;


--
-- Name: pub; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pub (
    pub_id integer NOT NULL,
    title text,
    volumetitle text,
    volume character varying(255),
    series_name character varying(255),
    issue character varying(255),
    pyear character varying(255),
    pages character varying(255),
    miniref character varying(255),
    uniquename text NOT NULL,
    type_id integer NOT NULL,
    is_obsolete boolean DEFAULT false,
    publisher character varying(255),
    pubplace character varying(255)
);


--
-- Name: TABLE pub; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE pub IS 'A documented provenance artefact - publications,
documents, personal communication.';


--
-- Name: COLUMN pub.title; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN pub.title IS 'Descriptive general heading.';


--
-- Name: COLUMN pub.volumetitle; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN pub.volumetitle IS 'Title of part if one of a series.';


--
-- Name: COLUMN pub.series_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN pub.series_name IS 'Full name of (journal) series.';


--
-- Name: COLUMN pub.pages; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN pub.pages IS 'Page number range[s], e.g. 457--459, viii + 664pp, lv--lvii.';


--
-- Name: COLUMN pub.type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN pub.type_id IS 'The type of the publication (book, journal, poem, graffiti, etc). Uses pub cv.';


--
-- Name: pub_dbxref; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pub_dbxref (
    pub_dbxref_id integer NOT NULL,
    pub_id integer NOT NULL,
    dbxref_id integer NOT NULL,
    is_current boolean DEFAULT true NOT NULL
);


--
-- Name: TABLE pub_dbxref; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE pub_dbxref IS 'Handle links to repositories,
e.g. Pubmed, Biosis, zoorec, OCLC, Medline, ISSN, coden...';


--
-- Name: pub_dbxref_pub_dbxref_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE pub_dbxref_pub_dbxref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: pub_dbxref_pub_dbxref_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE pub_dbxref_pub_dbxref_id_seq OWNED BY pub_dbxref.pub_dbxref_id;


--
-- Name: pub_pub_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE pub_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: pub_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE pub_pub_id_seq OWNED BY pub.pub_id;


--
-- Name: pub_relationship; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pub_relationship (
    pub_relationship_id integer NOT NULL,
    subject_id integer NOT NULL,
    object_id integer NOT NULL,
    type_id integer NOT NULL
);


--
-- Name: TABLE pub_relationship; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE pub_relationship IS 'Handle relationships between
publications, e.g. when one publication makes others obsolete, when one
publication contains errata with respect to other publication(s), or
when one publication also appears in another pub.';


--
-- Name: pub_relationship_pub_relationship_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE pub_relationship_pub_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: pub_relationship_pub_relationship_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE pub_relationship_pub_relationship_id_seq OWNED BY pub_relationship.pub_relationship_id;


--
-- Name: pubauthor; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pubauthor (
    pubauthor_id integer NOT NULL,
    pub_id integer NOT NULL,
    rank integer NOT NULL,
    editor boolean DEFAULT false,
    surname character varying(100) NOT NULL,
    givennames character varying(100),
    suffix character varying(100)
);


--
-- Name: TABLE pubauthor; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE pubauthor IS 'An author for a publication. Note the denormalisation (hence lack of _ in table name) - this is deliberate as it is in general too hard to assign IDs to authors.';


--
-- Name: COLUMN pubauthor.rank; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN pubauthor.rank IS 'Order of author in author list for this pub - order is important.';


--
-- Name: COLUMN pubauthor.editor; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN pubauthor.editor IS 'Indicates whether the author is an editor for linked publication. Note: this is a boolean field but does not follow the normal chado convention for naming booleans.';


--
-- Name: COLUMN pubauthor.givennames; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN pubauthor.givennames IS 'First name, initials';


--
-- Name: COLUMN pubauthor.suffix; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN pubauthor.suffix IS 'Jr., Sr., etc';


--
-- Name: pubauthor_pubauthor_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE pubauthor_pubauthor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: pubauthor_pubauthor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE pubauthor_pubauthor_id_seq OWNED BY pubauthor.pubauthor_id;


--
-- Name: pubprop; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pubprop (
    pubprop_id integer NOT NULL,
    pub_id integer NOT NULL,
    type_id integer NOT NULL,
    value text NOT NULL,
    rank integer
);


--
-- Name: TABLE pubprop; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE pubprop IS 'Property-value pairs for a pub. Follows standard chado pattern.';


--
-- Name: pubprop_pubprop_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE pubprop_pubprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: pubprop_pubprop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE pubprop_pubprop_id_seq OWNED BY pubprop.pubprop_id;


--
-- Name: stock; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE stock (
    stock_id integer NOT NULL,
    dbxref_id integer,
    organism_id integer,
    name character varying(255),
    uniquename text NOT NULL,
    description text,
    type_id integer NOT NULL,
    is_obsolete boolean DEFAULT false NOT NULL
);


--
-- Name: TABLE stock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE stock IS 'Any stock can be globally identified by the
combination of organism, uniquename and stock type. A stock is the physical entities, either living or preserved, held by collections. Stocks belong to a collection; they have IDs, type, organism, description and may have a genotype.';


--
-- Name: COLUMN stock.dbxref_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN stock.dbxref_id IS 'The dbxref_id is an optional primary stable identifier for this stock. Secondary indentifiers and external dbxrefs go in table: stock_dbxref.';


--
-- Name: COLUMN stock.organism_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN stock.organism_id IS 'The organism_id is the organism to which the stock belongs. This column should only be left blank if the organism cannot be determined.';


--
-- Name: COLUMN stock.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN stock.name IS 'The name is a human-readable local name for a stock.';


--
-- Name: COLUMN stock.description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN stock.description IS 'The description is the genetic description provided in the stock list.';


--
-- Name: COLUMN stock.type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN stock.type_id IS 'The type_id foreign key links to a controlled vocabulary of stock types. The would include living stock, genomic DNA, preserved specimen. Secondary cvterms for stocks would go in stock_cvterm.';


--
-- Name: stock_cvterm; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE stock_cvterm (
    stock_cvterm_id integer NOT NULL,
    stock_id integer NOT NULL,
    cvterm_id integer NOT NULL,
    pub_id integer NOT NULL,
    is_not boolean DEFAULT false NOT NULL,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE stock_cvterm; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE stock_cvterm IS 'stock_cvterm links a stock to cvterms. This is for secondary cvterms; primary cvterms should use stock.type_id.';


--
-- Name: stock_cvterm_stock_cvterm_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE stock_cvterm_stock_cvterm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: stock_cvterm_stock_cvterm_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE stock_cvterm_stock_cvterm_id_seq OWNED BY stock_cvterm.stock_cvterm_id;


--
-- Name: stock_cvtermprop; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE stock_cvtermprop (
    stock_cvtermprop_id integer NOT NULL,
    stock_cvterm_id integer NOT NULL,
    type_id integer NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE stock_cvtermprop; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE stock_cvtermprop IS 'Extensible properties for
stock to cvterm associations. Examples: GO evidence codes;
qualifiers; metadata such as the date on which the entry was curated
and the source of the association. See the stockprop table for
meanings of type_id, value and rank.';


--
-- Name: COLUMN stock_cvtermprop.type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN stock_cvtermprop.type_id IS 'The name of the
property/slot is a cvterm. The meaning of the property is defined in
that cvterm. cvterms may come from the OBO evidence code cv.';


--
-- Name: COLUMN stock_cvtermprop.value; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN stock_cvtermprop.value IS 'The value of the
property, represented as text. Numeric values are converted to their
text representation. This is less efficient than using native database
types, but is easier to query.';


--
-- Name: COLUMN stock_cvtermprop.rank; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN stock_cvtermprop.rank IS 'Property-Value
ordering. Any stock_cvterm can have multiple values for any particular
property type - these are ordered in a list using rank, counting from
zero. For properties that are single-valued rather than multi-valued,
the default 0 value should be used.';


--
-- Name: stock_cvtermprop_stock_cvtermprop_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE stock_cvtermprop_stock_cvtermprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: stock_cvtermprop_stock_cvtermprop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE stock_cvtermprop_stock_cvtermprop_id_seq OWNED BY stock_cvtermprop.stock_cvtermprop_id;


--
-- Name: stock_dbxref; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE stock_dbxref (
    stock_dbxref_id integer NOT NULL,
    stock_id integer NOT NULL,
    dbxref_id integer NOT NULL,
    is_current boolean DEFAULT true NOT NULL
);


--
-- Name: TABLE stock_dbxref; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE stock_dbxref IS 'stock_dbxref links a stock to dbxrefs. This is for secondary identifiers; primary identifiers should use stock.dbxref_id.';


--
-- Name: COLUMN stock_dbxref.is_current; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN stock_dbxref.is_current IS 'The is_current boolean indicates whether the linked dbxref is the current -official- dbxref for the linked stock.';


--
-- Name: stock_dbxref_stock_dbxref_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE stock_dbxref_stock_dbxref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: stock_dbxref_stock_dbxref_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE stock_dbxref_stock_dbxref_id_seq OWNED BY stock_dbxref.stock_dbxref_id;


--
-- Name: stock_dbxrefprop; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE stock_dbxrefprop (
    stock_dbxrefprop_id integer NOT NULL,
    stock_dbxref_id integer NOT NULL,
    type_id integer NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE stock_dbxrefprop; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE stock_dbxrefprop IS 'A stock_dbxref can have any number of
slot-value property tags attached to it. This is useful for storing properties related to dbxref annotations of stocks, such as evidence codes, and references, and metadata, such as create/modify dates. This is an alternative to
hardcoding a list of columns in the relational schema, and is
completely extensible. There is a unique constraint, stock_dbxrefprop_c1, for
the combination of stock_dbxref_id, rank, and type_id. Multivalued property-value pairs must be differentiated by rank.';


--
-- Name: stock_dbxrefprop_stock_dbxrefprop_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE stock_dbxrefprop_stock_dbxrefprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: stock_dbxrefprop_stock_dbxrefprop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE stock_dbxrefprop_stock_dbxrefprop_id_seq OWNED BY stock_dbxrefprop.stock_dbxrefprop_id;


--
-- Name: stock_genotype; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE stock_genotype (
    stock_genotype_id integer NOT NULL,
    stock_id integer NOT NULL,
    genotype_id integer NOT NULL
);


--
-- Name: TABLE stock_genotype; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE stock_genotype IS 'Simple table linking a stock to
a genotype. Features with genotypes can be linked to stocks thru feature_genotype -> genotype -> stock_genotype -> stock.';


--
-- Name: stock_genotype_stock_genotype_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE stock_genotype_stock_genotype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: stock_genotype_stock_genotype_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE stock_genotype_stock_genotype_id_seq OWNED BY stock_genotype.stock_genotype_id;


--
-- Name: stock_pub; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE stock_pub (
    stock_pub_id integer NOT NULL,
    stock_id integer NOT NULL,
    pub_id integer NOT NULL
);


--
-- Name: TABLE stock_pub; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE stock_pub IS 'Provenance. Linking table between stocks and, for example, a stocklist computer file.';


--
-- Name: stock_pub_stock_pub_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE stock_pub_stock_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: stock_pub_stock_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE stock_pub_stock_pub_id_seq OWNED BY stock_pub.stock_pub_id;


--
-- Name: stock_relationship; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE stock_relationship (
    stock_relationship_id integer NOT NULL,
    subject_id integer NOT NULL,
    object_id integer NOT NULL,
    type_id integer NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: COLUMN stock_relationship.subject_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN stock_relationship.subject_id IS 'stock_relationship.subject_id is the subject of the subj-predicate-obj sentence. This is typically the substock.';


--
-- Name: COLUMN stock_relationship.object_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN stock_relationship.object_id IS 'stock_relationship.object_id is the object of the subj-predicate-obj sentence. This is typically the container stock.';


--
-- Name: COLUMN stock_relationship.type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN stock_relationship.type_id IS 'stock_relationship.type_id is relationship type between subject and object. This is a cvterm, typically from the OBO relationship ontology, although other relationship types are allowed.';


--
-- Name: COLUMN stock_relationship.value; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN stock_relationship.value IS 'stock_relationship.value is for additional notes or comments.';


--
-- Name: COLUMN stock_relationship.rank; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN stock_relationship.rank IS 'stock_relationship.rank is the ordering of subject stocks with respect to the object stock may be important where rank is used to order these; starts from zero.';


--
-- Name: stock_relationship_cvterm; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE stock_relationship_cvterm (
    stock_relationship_cvterm_id integer NOT NULL,
    stock_relationship_id integer NOT NULL,
    cvterm_id integer NOT NULL,
    pub_id integer
);


--
-- Name: TABLE stock_relationship_cvterm; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE stock_relationship_cvterm IS 'For germplasm maintenance and pedigree data, stock_relationship. type_id will record cvterms such as "is a female parent of", "a parent for mutation", "is a group_id of", "is a source_id of", etc The cvterms for higher categories such as "generative", "derivative" or "maintenance" can be stored in table stock_relationship_cvterm';


--
-- Name: stock_relationship_cvterm_stock_relationship_cvterm_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE stock_relationship_cvterm_stock_relationship_cvterm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: stock_relationship_cvterm_stock_relationship_cvterm_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE stock_relationship_cvterm_stock_relationship_cvterm_id_seq OWNED BY stock_relationship_cvterm.stock_relationship_cvterm_id;


--
-- Name: stock_relationship_pub; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE stock_relationship_pub (
    stock_relationship_pub_id integer NOT NULL,
    stock_relationship_id integer NOT NULL,
    pub_id integer NOT NULL
);


--
-- Name: TABLE stock_relationship_pub; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE stock_relationship_pub IS 'Provenance. Attach optional evidence to a stock_relationship in the form of a publication.';


--
-- Name: stock_relationship_pub_stock_relationship_pub_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE stock_relationship_pub_stock_relationship_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: stock_relationship_pub_stock_relationship_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE stock_relationship_pub_stock_relationship_pub_id_seq OWNED BY stock_relationship_pub.stock_relationship_pub_id;


--
-- Name: stock_relationship_stock_relationship_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE stock_relationship_stock_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: stock_relationship_stock_relationship_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE stock_relationship_stock_relationship_id_seq OWNED BY stock_relationship.stock_relationship_id;


--
-- Name: stock_stock_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE stock_stock_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: stock_stock_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE stock_stock_id_seq OWNED BY stock.stock_id;


--
-- Name: stockcollection; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE stockcollection (
    stockcollection_id integer NOT NULL,
    type_id integer NOT NULL,
    contact_id integer,
    name character varying(255),
    uniquename text NOT NULL
);


--
-- Name: TABLE stockcollection; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE stockcollection IS 'The lab or stock center distributing the stocks in their collection.';


--
-- Name: COLUMN stockcollection.type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN stockcollection.type_id IS 'type_id is the collection type cv.';


--
-- Name: COLUMN stockcollection.contact_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN stockcollection.contact_id IS 'contact_id links to the contact information for the collection.';


--
-- Name: COLUMN stockcollection.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN stockcollection.name IS 'name is the collection.';


--
-- Name: COLUMN stockcollection.uniquename; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN stockcollection.uniquename IS 'uniqename is the value of the collection cv.';


--
-- Name: stockcollection_stock; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE stockcollection_stock (
    stockcollection_stock_id integer NOT NULL,
    stockcollection_id integer NOT NULL,
    stock_id integer NOT NULL
);


--
-- Name: TABLE stockcollection_stock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE stockcollection_stock IS 'stockcollection_stock links
a stock collection to the stocks which are contained in the collection.';


--
-- Name: stockcollection_stock_stockcollection_stock_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE stockcollection_stock_stockcollection_stock_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: stockcollection_stock_stockcollection_stock_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE stockcollection_stock_stockcollection_stock_id_seq OWNED BY stockcollection_stock.stockcollection_stock_id;


--
-- Name: stockcollection_stockcollection_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE stockcollection_stockcollection_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: stockcollection_stockcollection_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE stockcollection_stockcollection_id_seq OWNED BY stockcollection.stockcollection_id;


--
-- Name: stockcollectionprop; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE stockcollectionprop (
    stockcollectionprop_id integer NOT NULL,
    stockcollection_id integer NOT NULL,
    type_id integer NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE stockcollectionprop; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE stockcollectionprop IS 'The table stockcollectionprop
contains the value of the stock collection such as website/email URLs;
the value of the stock collection order URLs.';


--
-- Name: COLUMN stockcollectionprop.type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN stockcollectionprop.type_id IS 'The cv for the type_id is "stockcollection property type".';


--
-- Name: stockcollectionprop_stockcollectionprop_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE stockcollectionprop_stockcollectionprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: stockcollectionprop_stockcollectionprop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE stockcollectionprop_stockcollectionprop_id_seq OWNED BY stockcollectionprop.stockcollectionprop_id;


--
-- Name: stockprop; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE stockprop (
    stockprop_id integer NOT NULL,
    stock_id integer NOT NULL,
    type_id integer NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE stockprop; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE stockprop IS 'A stock can have any number of
slot-value property tags attached to it. This is an alternative to
hardcoding a list of columns in the relational schema, and is
completely extensible. There is a unique constraint, stockprop_c1, for
the combination of stock_id, rank, and type_id. Multivalued property-value pairs must be differentiated by rank.';


--
-- Name: stockprop_pub; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE stockprop_pub (
    stockprop_pub_id integer NOT NULL,
    stockprop_id integer NOT NULL,
    pub_id integer NOT NULL
);


--
-- Name: TABLE stockprop_pub; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE stockprop_pub IS 'Provenance. Any stockprop assignment can optionally be supported by a publication.';


--
-- Name: stockprop_pub_stockprop_pub_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE stockprop_pub_stockprop_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: stockprop_pub_stockprop_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE stockprop_pub_stockprop_pub_id_seq OWNED BY stockprop_pub.stockprop_pub_id;


--
-- Name: stockprop_stockprop_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE stockprop_stockprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: stockprop_stockprop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE stockprop_stockprop_id_seq OWNED BY stockprop.stockprop_id;


--
-- Name: synonym; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE synonym (
    synonym_id integer NOT NULL,
    name character varying(255) NOT NULL,
    type_id integer NOT NULL,
    synonym_sgml character varying(255) NOT NULL
);


--
-- Name: TABLE synonym; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE synonym IS 'A synonym for a feature. One feature can have multiple synonyms, and the same synonym can apply to multiple features.';


--
-- Name: COLUMN synonym.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN synonym.name IS 'The synonym itself. Should be human-readable machine-searchable ascii text.';


--
-- Name: COLUMN synonym.type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN synonym.type_id IS 'Types would be symbol and fullname for now.';


--
-- Name: COLUMN synonym.synonym_sgml; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN synonym.synonym_sgml IS 'The fully specified synonym, with any non-ascii characters encoded in SGML.';


--
-- Name: synonym_synonym_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE synonym_synonym_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: synonym_synonym_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE synonym_synonym_id_seq OWNED BY synonym.synonym_id;


--
-- Name: tableinfo; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE tableinfo (
    tableinfo_id integer NOT NULL,
    name character varying(30) NOT NULL,
    primary_key_column character varying(30),
    is_view integer DEFAULT 0 NOT NULL,
    view_on_table_id integer,
    superclass_table_id integer,
    is_updateable integer DEFAULT 1 NOT NULL,
    modification_date date DEFAULT now() NOT NULL
);


--
-- Name: tableinfo_tableinfo_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE tableinfo_tableinfo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: tableinfo_tableinfo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE tableinfo_tableinfo_id_seq OWNED BY tableinfo.tableinfo_id;


--
-- Name: chadoprop_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE chadoprop ALTER COLUMN chadoprop_id SET DEFAULT nextval('chadoprop_chadoprop_id_seq'::regclass);


--
-- Name: contact_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE contact ALTER COLUMN contact_id SET DEFAULT nextval('contact_contact_id_seq'::regclass);


--
-- Name: contact_relationship_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE contact_relationship ALTER COLUMN contact_relationship_id SET DEFAULT nextval('contact_relationship_contact_relationship_id_seq'::regclass);


--
-- Name: cv_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE cv ALTER COLUMN cv_id SET DEFAULT nextval('cv_cv_id_seq'::regclass);


--
-- Name: cvprop_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE cvprop ALTER COLUMN cvprop_id SET DEFAULT nextval('cvprop_cvprop_id_seq'::regclass);


--
-- Name: cvterm_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE cvterm ALTER COLUMN cvterm_id SET DEFAULT nextval('cvterm_cvterm_id_seq'::regclass);


--
-- Name: cvterm_dbxref_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE cvterm_dbxref ALTER COLUMN cvterm_dbxref_id SET DEFAULT nextval('cvterm_dbxref_cvterm_dbxref_id_seq'::regclass);


--
-- Name: cvterm_relationship_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE cvterm_relationship ALTER COLUMN cvterm_relationship_id SET DEFAULT nextval('cvterm_relationship_cvterm_relationship_id_seq'::regclass);


--
-- Name: cvtermpath_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE cvtermpath ALTER COLUMN cvtermpath_id SET DEFAULT nextval('cvtermpath_cvtermpath_id_seq'::regclass);


--
-- Name: cvtermprop_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE cvtermprop ALTER COLUMN cvtermprop_id SET DEFAULT nextval('cvtermprop_cvtermprop_id_seq'::regclass);


--
-- Name: cvtermsynonym_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE cvtermsynonym ALTER COLUMN cvtermsynonym_id SET DEFAULT nextval('cvtermsynonym_cvtermsynonym_id_seq'::regclass);


--
-- Name: db_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE db ALTER COLUMN db_id SET DEFAULT nextval('db_db_id_seq'::regclass);


--
-- Name: dbxref_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE dbxref ALTER COLUMN dbxref_id SET DEFAULT nextval('dbxref_dbxref_id_seq'::regclass);


--
-- Name: dbxrefprop_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE dbxrefprop ALTER COLUMN dbxrefprop_id SET DEFAULT nextval('dbxrefprop_dbxrefprop_id_seq'::regclass);


--
-- Name: environment_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE environment ALTER COLUMN environment_id SET DEFAULT nextval('environment_environment_id_seq'::regclass);


--
-- Name: environment_cvterm_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE environment_cvterm ALTER COLUMN environment_cvterm_id SET DEFAULT nextval('environment_cvterm_environment_cvterm_id_seq'::regclass);


--
-- Name: feature_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE feature ALTER COLUMN feature_id SET DEFAULT nextval('feature_feature_id_seq'::regclass);


--
-- Name: feature_cvterm_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE feature_cvterm ALTER COLUMN feature_cvterm_id SET DEFAULT nextval('feature_cvterm_feature_cvterm_id_seq'::regclass);


--
-- Name: feature_cvterm_dbxref_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE feature_cvterm_dbxref ALTER COLUMN feature_cvterm_dbxref_id SET DEFAULT nextval('feature_cvterm_dbxref_feature_cvterm_dbxref_id_seq'::regclass);


--
-- Name: feature_cvterm_pub_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE feature_cvterm_pub ALTER COLUMN feature_cvterm_pub_id SET DEFAULT nextval('feature_cvterm_pub_feature_cvterm_pub_id_seq'::regclass);


--
-- Name: feature_cvtermprop_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE feature_cvtermprop ALTER COLUMN feature_cvtermprop_id SET DEFAULT nextval('feature_cvtermprop_feature_cvtermprop_id_seq'::regclass);


--
-- Name: feature_dbxref_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE feature_dbxref ALTER COLUMN feature_dbxref_id SET DEFAULT nextval('feature_dbxref_feature_dbxref_id_seq'::regclass);


--
-- Name: feature_genotype_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE feature_genotype ALTER COLUMN feature_genotype_id SET DEFAULT nextval('feature_genotype_feature_genotype_id_seq'::regclass);


--
-- Name: feature_phenotype_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE feature_phenotype ALTER COLUMN feature_phenotype_id SET DEFAULT nextval('feature_phenotype_feature_phenotype_id_seq'::regclass);


--
-- Name: feature_pub_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE feature_pub ALTER COLUMN feature_pub_id SET DEFAULT nextval('feature_pub_feature_pub_id_seq'::regclass);


--
-- Name: feature_pubprop_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE feature_pubprop ALTER COLUMN feature_pubprop_id SET DEFAULT nextval('feature_pubprop_feature_pubprop_id_seq'::regclass);


--
-- Name: feature_relationship_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE feature_relationship ALTER COLUMN feature_relationship_id SET DEFAULT nextval('feature_relationship_feature_relationship_id_seq'::regclass);


--
-- Name: feature_relationship_pub_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE feature_relationship_pub ALTER COLUMN feature_relationship_pub_id SET DEFAULT nextval('feature_relationship_pub_feature_relationship_pub_id_seq'::regclass);


--
-- Name: feature_relationshipprop_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE feature_relationshipprop ALTER COLUMN feature_relationshipprop_id SET DEFAULT nextval('feature_relationshipprop_feature_relationshipprop_id_seq'::regclass);


--
-- Name: feature_relationshipprop_pub_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE feature_relationshipprop_pub ALTER COLUMN feature_relationshipprop_pub_id SET DEFAULT nextval('feature_relationshipprop_pub_feature_relationshipprop_pub_i_seq'::regclass);


--
-- Name: feature_synonym_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE feature_synonym ALTER COLUMN feature_synonym_id SET DEFAULT nextval('feature_synonym_feature_synonym_id_seq'::regclass);


--
-- Name: featureloc_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE featureloc ALTER COLUMN featureloc_id SET DEFAULT nextval('featureloc_featureloc_id_seq'::regclass);


--
-- Name: featureloc_pub_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE featureloc_pub ALTER COLUMN featureloc_pub_id SET DEFAULT nextval('featureloc_pub_featureloc_pub_id_seq'::regclass);


--
-- Name: featureprop_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE featureprop ALTER COLUMN featureprop_id SET DEFAULT nextval('featureprop_featureprop_id_seq'::regclass);


--
-- Name: featureprop_pub_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE featureprop_pub ALTER COLUMN featureprop_pub_id SET DEFAULT nextval('featureprop_pub_featureprop_pub_id_seq'::regclass);


--
-- Name: genotype_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE genotype ALTER COLUMN genotype_id SET DEFAULT nextval('genotype_genotype_id_seq'::regclass);


--
-- Name: genotypeprop_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE genotypeprop ALTER COLUMN genotypeprop_id SET DEFAULT nextval('genotypeprop_genotypeprop_id_seq'::regclass);


--
-- Name: nd_experiment_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE nd_experiment ALTER COLUMN nd_experiment_id SET DEFAULT nextval('nd_experiment_nd_experiment_id_seq'::regclass);


--
-- Name: nd_experiment_contact_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE nd_experiment_contact ALTER COLUMN nd_experiment_contact_id SET DEFAULT nextval('nd_experiment_contact_nd_experiment_contact_id_seq'::regclass);


--
-- Name: nd_experiment_dbxref_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE nd_experiment_dbxref ALTER COLUMN nd_experiment_dbxref_id SET DEFAULT nextval('nd_experiment_dbxref_nd_experiment_dbxref_id_seq'::regclass);


--
-- Name: nd_experiment_genotype_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE nd_experiment_genotype ALTER COLUMN nd_experiment_genotype_id SET DEFAULT nextval('nd_experiment_genotype_nd_experiment_genotype_id_seq'::regclass);


--
-- Name: nd_experiment_phenotype_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE nd_experiment_phenotype ALTER COLUMN nd_experiment_phenotype_id SET DEFAULT nextval('nd_experiment_phenotype_nd_experiment_phenotype_id_seq'::regclass);


--
-- Name: nd_experiment_project_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE nd_experiment_project ALTER COLUMN nd_experiment_project_id SET DEFAULT nextval('nd_experiment_project_nd_experiment_project_id_seq'::regclass);


--
-- Name: nd_experiment_protocol_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE nd_experiment_protocol ALTER COLUMN nd_experiment_protocol_id SET DEFAULT nextval('nd_experiment_protocol_nd_experiment_protocol_id_seq'::regclass);


--
-- Name: nd_experiment_pub_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE nd_experiment_pub ALTER COLUMN nd_experiment_pub_id SET DEFAULT nextval('nd_experiment_pub_nd_experiment_pub_id_seq'::regclass);


--
-- Name: nd_experiment_stock_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE nd_experiment_stock ALTER COLUMN nd_experiment_stock_id SET DEFAULT nextval('nd_experiment_stock_nd_experiment_stock_id_seq'::regclass);


--
-- Name: nd_experiment_stock_dbxref_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE nd_experiment_stock_dbxref ALTER COLUMN nd_experiment_stock_dbxref_id SET DEFAULT nextval('nd_experiment_stock_dbxref_nd_experiment_stock_dbxref_id_seq'::regclass);


--
-- Name: nd_experiment_stockprop_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE nd_experiment_stockprop ALTER COLUMN nd_experiment_stockprop_id SET DEFAULT nextval('nd_experiment_stockprop_nd_experiment_stockprop_id_seq'::regclass);


--
-- Name: nd_experimentprop_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE nd_experimentprop ALTER COLUMN nd_experimentprop_id SET DEFAULT nextval('nd_experimentprop_nd_experimentprop_id_seq'::regclass);


--
-- Name: nd_geolocation_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE nd_geolocation ALTER COLUMN nd_geolocation_id SET DEFAULT nextval('nd_geolocation_nd_geolocation_id_seq'::regclass);


--
-- Name: nd_geolocationprop_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE nd_geolocationprop ALTER COLUMN nd_geolocationprop_id SET DEFAULT nextval('nd_geolocationprop_nd_geolocationprop_id_seq'::regclass);


--
-- Name: nd_protocol_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE nd_protocol ALTER COLUMN nd_protocol_id SET DEFAULT nextval('nd_protocol_nd_protocol_id_seq'::regclass);


--
-- Name: nd_protocol_reagent_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE nd_protocol_reagent ALTER COLUMN nd_protocol_reagent_id SET DEFAULT nextval('nd_protocol_reagent_nd_protocol_reagent_id_seq'::regclass);


--
-- Name: nd_protocolprop_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE nd_protocolprop ALTER COLUMN nd_protocolprop_id SET DEFAULT nextval('nd_protocolprop_nd_protocolprop_id_seq'::regclass);


--
-- Name: nd_reagent_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE nd_reagent ALTER COLUMN nd_reagent_id SET DEFAULT nextval('nd_reagent_nd_reagent_id_seq'::regclass);


--
-- Name: nd_reagent_relationship_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE nd_reagent_relationship ALTER COLUMN nd_reagent_relationship_id SET DEFAULT nextval('nd_reagent_relationship_nd_reagent_relationship_id_seq'::regclass);


--
-- Name: nd_reagentprop_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE nd_reagentprop ALTER COLUMN nd_reagentprop_id SET DEFAULT nextval('nd_reagentprop_nd_reagentprop_id_seq'::regclass);


--
-- Name: organism_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE organism ALTER COLUMN organism_id SET DEFAULT nextval('organism_organism_id_seq'::regclass);


--
-- Name: organism_dbxref_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE organism_dbxref ALTER COLUMN organism_dbxref_id SET DEFAULT nextval('organism_dbxref_organism_dbxref_id_seq'::regclass);


--
-- Name: organismprop_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE organismprop ALTER COLUMN organismprop_id SET DEFAULT nextval('organismprop_organismprop_id_seq'::regclass);


--
-- Name: phendesc_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE phendesc ALTER COLUMN phendesc_id SET DEFAULT nextval('phendesc_phendesc_id_seq'::regclass);


--
-- Name: phenotype_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE phenotype ALTER COLUMN phenotype_id SET DEFAULT nextval('phenotype_phenotype_id_seq'::regclass);


--
-- Name: phenotype_comparison_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE phenotype_comparison ALTER COLUMN phenotype_comparison_id SET DEFAULT nextval('phenotype_comparison_phenotype_comparison_id_seq'::regclass);


--
-- Name: phenotype_comparison_cvterm_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE phenotype_comparison_cvterm ALTER COLUMN phenotype_comparison_cvterm_id SET DEFAULT nextval('phenotype_comparison_cvterm_phenotype_comparison_cvterm_id_seq'::regclass);


--
-- Name: phenotype_cvterm_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE phenotype_cvterm ALTER COLUMN phenotype_cvterm_id SET DEFAULT nextval('phenotype_cvterm_phenotype_cvterm_id_seq'::regclass);


--
-- Name: phenotypeprop_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE phenotypeprop ALTER COLUMN phenotypeprop_id SET DEFAULT nextval('phenotypeprop_phenotypeprop_id_seq'::regclass);


--
-- Name: phenstatement_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE phenstatement ALTER COLUMN phenstatement_id SET DEFAULT nextval('phenstatement_phenstatement_id_seq'::regclass);


--
-- Name: project_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE project ALTER COLUMN project_id SET DEFAULT nextval('project_project_id_seq'::regclass);


--
-- Name: project_contact_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE project_contact ALTER COLUMN project_contact_id SET DEFAULT nextval('project_contact_project_contact_id_seq'::regclass);


--
-- Name: project_pub_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE project_pub ALTER COLUMN project_pub_id SET DEFAULT nextval('project_pub_project_pub_id_seq'::regclass);


--
-- Name: project_relationship_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE project_relationship ALTER COLUMN project_relationship_id SET DEFAULT nextval('project_relationship_project_relationship_id_seq'::regclass);


--
-- Name: projectprop_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE projectprop ALTER COLUMN projectprop_id SET DEFAULT nextval('projectprop_projectprop_id_seq'::regclass);


--
-- Name: pub_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE pub ALTER COLUMN pub_id SET DEFAULT nextval('pub_pub_id_seq'::regclass);


--
-- Name: pub_dbxref_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE pub_dbxref ALTER COLUMN pub_dbxref_id SET DEFAULT nextval('pub_dbxref_pub_dbxref_id_seq'::regclass);


--
-- Name: pub_relationship_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE pub_relationship ALTER COLUMN pub_relationship_id SET DEFAULT nextval('pub_relationship_pub_relationship_id_seq'::regclass);


--
-- Name: pubauthor_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE pubauthor ALTER COLUMN pubauthor_id SET DEFAULT nextval('pubauthor_pubauthor_id_seq'::regclass);


--
-- Name: pubprop_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE pubprop ALTER COLUMN pubprop_id SET DEFAULT nextval('pubprop_pubprop_id_seq'::regclass);


--
-- Name: stock_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE stock ALTER COLUMN stock_id SET DEFAULT nextval('stock_stock_id_seq'::regclass);


--
-- Name: stock_cvterm_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE stock_cvterm ALTER COLUMN stock_cvterm_id SET DEFAULT nextval('stock_cvterm_stock_cvterm_id_seq'::regclass);


--
-- Name: stock_cvtermprop_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE stock_cvtermprop ALTER COLUMN stock_cvtermprop_id SET DEFAULT nextval('stock_cvtermprop_stock_cvtermprop_id_seq'::regclass);


--
-- Name: stock_dbxref_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE stock_dbxref ALTER COLUMN stock_dbxref_id SET DEFAULT nextval('stock_dbxref_stock_dbxref_id_seq'::regclass);


--
-- Name: stock_dbxrefprop_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE stock_dbxrefprop ALTER COLUMN stock_dbxrefprop_id SET DEFAULT nextval('stock_dbxrefprop_stock_dbxrefprop_id_seq'::regclass);


--
-- Name: stock_genotype_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE stock_genotype ALTER COLUMN stock_genotype_id SET DEFAULT nextval('stock_genotype_stock_genotype_id_seq'::regclass);


--
-- Name: stock_pub_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE stock_pub ALTER COLUMN stock_pub_id SET DEFAULT nextval('stock_pub_stock_pub_id_seq'::regclass);


--
-- Name: stock_relationship_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE stock_relationship ALTER COLUMN stock_relationship_id SET DEFAULT nextval('stock_relationship_stock_relationship_id_seq'::regclass);


--
-- Name: stock_relationship_cvterm_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE stock_relationship_cvterm ALTER COLUMN stock_relationship_cvterm_id SET DEFAULT nextval('stock_relationship_cvterm_stock_relationship_cvterm_id_seq'::regclass);


--
-- Name: stock_relationship_pub_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE stock_relationship_pub ALTER COLUMN stock_relationship_pub_id SET DEFAULT nextval('stock_relationship_pub_stock_relationship_pub_id_seq'::regclass);


--
-- Name: stockcollection_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE stockcollection ALTER COLUMN stockcollection_id SET DEFAULT nextval('stockcollection_stockcollection_id_seq'::regclass);


--
-- Name: stockcollection_stock_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE stockcollection_stock ALTER COLUMN stockcollection_stock_id SET DEFAULT nextval('stockcollection_stock_stockcollection_stock_id_seq'::regclass);


--
-- Name: stockcollectionprop_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE stockcollectionprop ALTER COLUMN stockcollectionprop_id SET DEFAULT nextval('stockcollectionprop_stockcollectionprop_id_seq'::regclass);


--
-- Name: stockprop_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE stockprop ALTER COLUMN stockprop_id SET DEFAULT nextval('stockprop_stockprop_id_seq'::regclass);


--
-- Name: stockprop_pub_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE stockprop_pub ALTER COLUMN stockprop_pub_id SET DEFAULT nextval('stockprop_pub_stockprop_pub_id_seq'::regclass);


--
-- Name: synonym_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE synonym ALTER COLUMN synonym_id SET DEFAULT nextval('synonym_synonym_id_seq'::regclass);


--
-- Name: tableinfo_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE tableinfo ALTER COLUMN tableinfo_id SET DEFAULT nextval('tableinfo_tableinfo_id_seq'::regclass);


--
-- Name: chadoprop_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY chadoprop
    ADD CONSTRAINT chadoprop_c1 UNIQUE (type_id, rank);


--
-- Name: chadoprop_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY chadoprop
    ADD CONSTRAINT chadoprop_pkey PRIMARY KEY (chadoprop_id);


--
-- Name: contact_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY contact
    ADD CONSTRAINT contact_c1 UNIQUE (name);


--
-- Name: contact_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY contact
    ADD CONSTRAINT contact_pkey PRIMARY KEY (contact_id);


--
-- Name: contact_relationship_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY contact_relationship
    ADD CONSTRAINT contact_relationship_c1 UNIQUE (subject_id, object_id, type_id);


--
-- Name: contact_relationship_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY contact_relationship
    ADD CONSTRAINT contact_relationship_pkey PRIMARY KEY (contact_relationship_id);


--
-- Name: cv_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY cv
    ADD CONSTRAINT cv_c1 UNIQUE (name);


--
-- Name: cv_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY cv
    ADD CONSTRAINT cv_pkey PRIMARY KEY (cv_id);


--
-- Name: cvprop_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY cvprop
    ADD CONSTRAINT cvprop_c1 UNIQUE (cv_id, type_id, rank);


--
-- Name: cvprop_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY cvprop
    ADD CONSTRAINT cvprop_pkey PRIMARY KEY (cvprop_id);


--
-- Name: cvterm_c2; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY cvterm
    ADD CONSTRAINT cvterm_c2 UNIQUE (dbxref_id);


--
-- Name: cvterm_dbxref_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY cvterm_dbxref
    ADD CONSTRAINT cvterm_dbxref_c1 UNIQUE (cvterm_id, dbxref_id);


--
-- Name: cvterm_dbxref_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY cvterm_dbxref
    ADD CONSTRAINT cvterm_dbxref_pkey PRIMARY KEY (cvterm_dbxref_id);


--
-- Name: cvterm_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY cvterm
    ADD CONSTRAINT cvterm_pkey PRIMARY KEY (cvterm_id);


--
-- Name: cvterm_relationship_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY cvterm_relationship
    ADD CONSTRAINT cvterm_relationship_c1 UNIQUE (subject_id, object_id, type_id);


--
-- Name: cvterm_relationship_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY cvterm_relationship
    ADD CONSTRAINT cvterm_relationship_pkey PRIMARY KEY (cvterm_relationship_id);


--
-- Name: cvtermpath_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY cvtermpath
    ADD CONSTRAINT cvtermpath_c1 UNIQUE (subject_id, object_id, type_id, pathdistance);


--
-- Name: cvtermpath_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY cvtermpath
    ADD CONSTRAINT cvtermpath_pkey PRIMARY KEY (cvtermpath_id);


--
-- Name: cvtermprop_cvterm_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY cvtermprop
    ADD CONSTRAINT cvtermprop_cvterm_id_key UNIQUE (cvterm_id, type_id, value, rank);


--
-- Name: cvtermprop_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY cvtermprop
    ADD CONSTRAINT cvtermprop_pkey PRIMARY KEY (cvtermprop_id);


--
-- Name: cvtermsynonym_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY cvtermsynonym
    ADD CONSTRAINT cvtermsynonym_c1 UNIQUE (cvterm_id, synonym);


--
-- Name: cvtermsynonym_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY cvtermsynonym
    ADD CONSTRAINT cvtermsynonym_pkey PRIMARY KEY (cvtermsynonym_id);


--
-- Name: db_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY db
    ADD CONSTRAINT db_c1 UNIQUE (name);


--
-- Name: db_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY db
    ADD CONSTRAINT db_pkey PRIMARY KEY (db_id);


--
-- Name: dbxref_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY dbxref
    ADD CONSTRAINT dbxref_c1 UNIQUE (db_id, accession, version);


--
-- Name: dbxref_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY dbxref
    ADD CONSTRAINT dbxref_pkey PRIMARY KEY (dbxref_id);


--
-- Name: dbxrefprop_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY dbxrefprop
    ADD CONSTRAINT dbxrefprop_c1 UNIQUE (dbxref_id, type_id, rank);


--
-- Name: dbxrefprop_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY dbxrefprop
    ADD CONSTRAINT dbxrefprop_pkey PRIMARY KEY (dbxrefprop_id);


--
-- Name: environment_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY environment
    ADD CONSTRAINT environment_c1 UNIQUE (uniquename);


--
-- Name: environment_cvterm_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY environment_cvterm
    ADD CONSTRAINT environment_cvterm_c1 UNIQUE (environment_id, cvterm_id);


--
-- Name: environment_cvterm_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY environment_cvterm
    ADD CONSTRAINT environment_cvterm_pkey PRIMARY KEY (environment_cvterm_id);


--
-- Name: environment_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY environment
    ADD CONSTRAINT environment_pkey PRIMARY KEY (environment_id);


--
-- Name: feature_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature
    ADD CONSTRAINT feature_c1 UNIQUE (organism_id, uniquename, type_id);


--
-- Name: feature_cvterm_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_cvterm
    ADD CONSTRAINT feature_cvterm_c1 UNIQUE (feature_id, cvterm_id, pub_id, rank);


--
-- Name: feature_cvterm_dbxref_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_cvterm_dbxref
    ADD CONSTRAINT feature_cvterm_dbxref_c1 UNIQUE (feature_cvterm_id, dbxref_id);


--
-- Name: feature_cvterm_dbxref_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_cvterm_dbxref
    ADD CONSTRAINT feature_cvterm_dbxref_pkey PRIMARY KEY (feature_cvterm_dbxref_id);


--
-- Name: feature_cvterm_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_cvterm
    ADD CONSTRAINT feature_cvterm_pkey PRIMARY KEY (feature_cvterm_id);


--
-- Name: feature_cvterm_pub_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_cvterm_pub
    ADD CONSTRAINT feature_cvterm_pub_c1 UNIQUE (feature_cvterm_id, pub_id);


--
-- Name: feature_cvterm_pub_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_cvterm_pub
    ADD CONSTRAINT feature_cvterm_pub_pkey PRIMARY KEY (feature_cvterm_pub_id);


--
-- Name: feature_cvtermprop_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_cvtermprop
    ADD CONSTRAINT feature_cvtermprop_c1 UNIQUE (feature_cvterm_id, type_id, rank);


--
-- Name: feature_cvtermprop_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_cvtermprop
    ADD CONSTRAINT feature_cvtermprop_pkey PRIMARY KEY (feature_cvtermprop_id);


--
-- Name: feature_dbxref_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_dbxref
    ADD CONSTRAINT feature_dbxref_c1 UNIQUE (feature_id, dbxref_id);


--
-- Name: feature_dbxref_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_dbxref
    ADD CONSTRAINT feature_dbxref_pkey PRIMARY KEY (feature_dbxref_id);


--
-- Name: feature_genotype_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_genotype
    ADD CONSTRAINT feature_genotype_c1 UNIQUE (feature_id, genotype_id, cvterm_id, chromosome_id, rank, cgroup);


--
-- Name: feature_genotype_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_genotype
    ADD CONSTRAINT feature_genotype_pkey PRIMARY KEY (feature_genotype_id);


--
-- Name: feature_phenotype_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_phenotype
    ADD CONSTRAINT feature_phenotype_c1 UNIQUE (feature_id, phenotype_id);


--
-- Name: feature_phenotype_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_phenotype
    ADD CONSTRAINT feature_phenotype_pkey PRIMARY KEY (feature_phenotype_id);


--
-- Name: feature_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature
    ADD CONSTRAINT feature_pkey PRIMARY KEY (feature_id);


--
-- Name: feature_pub_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_pub
    ADD CONSTRAINT feature_pub_c1 UNIQUE (feature_id, pub_id);


--
-- Name: feature_pub_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_pub
    ADD CONSTRAINT feature_pub_pkey PRIMARY KEY (feature_pub_id);


--
-- Name: feature_pubprop_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_pubprop
    ADD CONSTRAINT feature_pubprop_c1 UNIQUE (feature_pub_id, type_id, rank);


--
-- Name: feature_pubprop_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_pubprop
    ADD CONSTRAINT feature_pubprop_pkey PRIMARY KEY (feature_pubprop_id);


--
-- Name: feature_relationship_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_relationship
    ADD CONSTRAINT feature_relationship_c1 UNIQUE (subject_id, object_id, type_id, rank);


--
-- Name: feature_relationship_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_relationship
    ADD CONSTRAINT feature_relationship_pkey PRIMARY KEY (feature_relationship_id);


--
-- Name: feature_relationship_pub_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_relationship_pub
    ADD CONSTRAINT feature_relationship_pub_c1 UNIQUE (feature_relationship_id, pub_id);


--
-- Name: feature_relationship_pub_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_relationship_pub
    ADD CONSTRAINT feature_relationship_pub_pkey PRIMARY KEY (feature_relationship_pub_id);


--
-- Name: feature_relationshipprop_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_relationshipprop
    ADD CONSTRAINT feature_relationshipprop_c1 UNIQUE (feature_relationship_id, type_id, rank);


--
-- Name: feature_relationshipprop_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_relationshipprop
    ADD CONSTRAINT feature_relationshipprop_pkey PRIMARY KEY (feature_relationshipprop_id);


--
-- Name: feature_relationshipprop_pub_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_relationshipprop_pub
    ADD CONSTRAINT feature_relationshipprop_pub_c1 UNIQUE (feature_relationshipprop_id, pub_id);


--
-- Name: feature_relationshipprop_pub_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_relationshipprop_pub
    ADD CONSTRAINT feature_relationshipprop_pub_pkey PRIMARY KEY (feature_relationshipprop_pub_id);


--
-- Name: feature_synonym_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_synonym
    ADD CONSTRAINT feature_synonym_c1 UNIQUE (synonym_id, feature_id, pub_id);


--
-- Name: feature_synonym_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY feature_synonym
    ADD CONSTRAINT feature_synonym_pkey PRIMARY KEY (feature_synonym_id);


--
-- Name: featureloc_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY featureloc
    ADD CONSTRAINT featureloc_c1 UNIQUE (feature_id, locgroup, rank);


--
-- Name: featureloc_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY featureloc
    ADD CONSTRAINT featureloc_pkey PRIMARY KEY (featureloc_id);


--
-- Name: featureloc_pub_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY featureloc_pub
    ADD CONSTRAINT featureloc_pub_c1 UNIQUE (featureloc_id, pub_id);


--
-- Name: featureloc_pub_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY featureloc_pub
    ADD CONSTRAINT featureloc_pub_pkey PRIMARY KEY (featureloc_pub_id);


--
-- Name: featureprop_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY featureprop
    ADD CONSTRAINT featureprop_c1 UNIQUE (feature_id, type_id, rank);


--
-- Name: featureprop_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY featureprop
    ADD CONSTRAINT featureprop_pkey PRIMARY KEY (featureprop_id);


--
-- Name: featureprop_pub_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY featureprop_pub
    ADD CONSTRAINT featureprop_pub_c1 UNIQUE (featureprop_id, pub_id);


--
-- Name: featureprop_pub_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY featureprop_pub
    ADD CONSTRAINT featureprop_pub_pkey PRIMARY KEY (featureprop_pub_id);


--
-- Name: genotype_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY genotype
    ADD CONSTRAINT genotype_c1 UNIQUE (uniquename);


--
-- Name: genotype_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY genotype
    ADD CONSTRAINT genotype_pkey PRIMARY KEY (genotype_id);


--
-- Name: genotypeprop_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY genotypeprop
    ADD CONSTRAINT genotypeprop_c1 UNIQUE (genotype_id, type_id, rank);


--
-- Name: genotypeprop_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY genotypeprop
    ADD CONSTRAINT genotypeprop_pkey PRIMARY KEY (genotypeprop_id);


--
-- Name: nd_experiment_contact_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_experiment_contact
    ADD CONSTRAINT nd_experiment_contact_pkey PRIMARY KEY (nd_experiment_contact_id);


--
-- Name: nd_experiment_dbxref_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_experiment_dbxref
    ADD CONSTRAINT nd_experiment_dbxref_pkey PRIMARY KEY (nd_experiment_dbxref_id);


--
-- Name: nd_experiment_genotype_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_experiment_genotype
    ADD CONSTRAINT nd_experiment_genotype_c1 UNIQUE (nd_experiment_id, genotype_id);


--
-- Name: nd_experiment_genotype_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_experiment_genotype
    ADD CONSTRAINT nd_experiment_genotype_pkey PRIMARY KEY (nd_experiment_genotype_id);


--
-- Name: nd_experiment_phenotype_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_experiment_phenotype
    ADD CONSTRAINT nd_experiment_phenotype_c1 UNIQUE (nd_experiment_id, phenotype_id);


--
-- Name: nd_experiment_phenotype_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_experiment_phenotype
    ADD CONSTRAINT nd_experiment_phenotype_pkey PRIMARY KEY (nd_experiment_phenotype_id);


--
-- Name: nd_experiment_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_experiment
    ADD CONSTRAINT nd_experiment_pkey PRIMARY KEY (nd_experiment_id);


--
-- Name: nd_experiment_project_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_experiment_project
    ADD CONSTRAINT nd_experiment_project_c1 UNIQUE (nd_experiment_id, project_id);


--
-- Name: nd_experiment_project_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_experiment_project
    ADD CONSTRAINT nd_experiment_project_pkey PRIMARY KEY (nd_experiment_project_id);


--
-- Name: nd_experiment_protocol_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_experiment_protocol
    ADD CONSTRAINT nd_experiment_protocol_pkey PRIMARY KEY (nd_experiment_protocol_id);


--
-- Name: nd_experiment_pub_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_experiment_pub
    ADD CONSTRAINT nd_experiment_pub_c1 UNIQUE (nd_experiment_id, pub_id);


--
-- Name: nd_experiment_pub_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_experiment_pub
    ADD CONSTRAINT nd_experiment_pub_pkey PRIMARY KEY (nd_experiment_pub_id);


--
-- Name: nd_experiment_stock_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_experiment_stock
    ADD CONSTRAINT nd_experiment_stock_c1 UNIQUE (nd_experiment_id, stock_id, type_id);


--
-- Name: nd_experiment_stock_dbxref_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_experiment_stock_dbxref
    ADD CONSTRAINT nd_experiment_stock_dbxref_pkey PRIMARY KEY (nd_experiment_stock_dbxref_id);


--
-- Name: nd_experiment_stock_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_experiment_stock
    ADD CONSTRAINT nd_experiment_stock_pkey PRIMARY KEY (nd_experiment_stock_id);


--
-- Name: nd_experiment_stockprop_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_experiment_stockprop
    ADD CONSTRAINT nd_experiment_stockprop_c1 UNIQUE (nd_experiment_stock_id, type_id, rank);


--
-- Name: nd_experiment_stockprop_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_experiment_stockprop
    ADD CONSTRAINT nd_experiment_stockprop_pkey PRIMARY KEY (nd_experiment_stockprop_id);


--
-- Name: nd_experimentprop_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_experimentprop
    ADD CONSTRAINT nd_experimentprop_c1 UNIQUE (nd_experiment_id, type_id, rank);


--
-- Name: nd_experimentprop_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_experimentprop
    ADD CONSTRAINT nd_experimentprop_pkey PRIMARY KEY (nd_experimentprop_id);


--
-- Name: nd_geolocation_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_geolocation
    ADD CONSTRAINT nd_geolocation_pkey PRIMARY KEY (nd_geolocation_id);


--
-- Name: nd_geolocationprop_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_geolocationprop
    ADD CONSTRAINT nd_geolocationprop_c1 UNIQUE (nd_geolocation_id, type_id, rank);


--
-- Name: nd_geolocationprop_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_geolocationprop
    ADD CONSTRAINT nd_geolocationprop_pkey PRIMARY KEY (nd_geolocationprop_id);


--
-- Name: nd_protocol_name_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_protocol
    ADD CONSTRAINT nd_protocol_name_key UNIQUE (name);


--
-- Name: nd_protocol_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_protocol
    ADD CONSTRAINT nd_protocol_pkey PRIMARY KEY (nd_protocol_id);


--
-- Name: nd_protocol_reagent_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_protocol_reagent
    ADD CONSTRAINT nd_protocol_reagent_pkey PRIMARY KEY (nd_protocol_reagent_id);


--
-- Name: nd_protocolprop_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_protocolprop
    ADD CONSTRAINT nd_protocolprop_c1 UNIQUE (nd_protocol_id, type_id, rank);


--
-- Name: nd_protocolprop_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_protocolprop
    ADD CONSTRAINT nd_protocolprop_pkey PRIMARY KEY (nd_protocolprop_id);


--
-- Name: nd_reagent_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_reagent
    ADD CONSTRAINT nd_reagent_pkey PRIMARY KEY (nd_reagent_id);


--
-- Name: nd_reagent_relationship_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_reagent_relationship
    ADD CONSTRAINT nd_reagent_relationship_pkey PRIMARY KEY (nd_reagent_relationship_id);


--
-- Name: nd_reagentprop_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_reagentprop
    ADD CONSTRAINT nd_reagentprop_c1 UNIQUE (nd_reagent_id, type_id, rank);


--
-- Name: nd_reagentprop_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nd_reagentprop
    ADD CONSTRAINT nd_reagentprop_pkey PRIMARY KEY (nd_reagentprop_id);


--
-- Name: organism_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY organism
    ADD CONSTRAINT organism_c1 UNIQUE (genus, species);


--
-- Name: organism_dbxref_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY organism_dbxref
    ADD CONSTRAINT organism_dbxref_c1 UNIQUE (organism_id, dbxref_id);


--
-- Name: organism_dbxref_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY organism_dbxref
    ADD CONSTRAINT organism_dbxref_pkey PRIMARY KEY (organism_dbxref_id);


--
-- Name: organism_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY organism
    ADD CONSTRAINT organism_pkey PRIMARY KEY (organism_id);


--
-- Name: organismprop_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY organismprop
    ADD CONSTRAINT organismprop_c1 UNIQUE (organism_id, type_id, rank);


--
-- Name: organismprop_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY organismprop
    ADD CONSTRAINT organismprop_pkey PRIMARY KEY (organismprop_id);


--
-- Name: phendesc_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY phendesc
    ADD CONSTRAINT phendesc_c1 UNIQUE (genotype_id, environment_id, type_id, pub_id);


--
-- Name: phendesc_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY phendesc
    ADD CONSTRAINT phendesc_pkey PRIMARY KEY (phendesc_id);


--
-- Name: phenotype_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY phenotype
    ADD CONSTRAINT phenotype_c1 UNIQUE (uniquename);


--
-- Name: phenotype_comparison_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY phenotype_comparison
    ADD CONSTRAINT phenotype_comparison_c1 UNIQUE (genotype1_id, environment1_id, genotype2_id, environment2_id, phenotype1_id, pub_id);


--
-- Name: phenotype_comparison_cvterm_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY phenotype_comparison_cvterm
    ADD CONSTRAINT phenotype_comparison_cvterm_c1 UNIQUE (phenotype_comparison_id, cvterm_id);


--
-- Name: phenotype_comparison_cvterm_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY phenotype_comparison_cvterm
    ADD CONSTRAINT phenotype_comparison_cvterm_pkey PRIMARY KEY (phenotype_comparison_cvterm_id);


--
-- Name: phenotype_comparison_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY phenotype_comparison
    ADD CONSTRAINT phenotype_comparison_pkey PRIMARY KEY (phenotype_comparison_id);


--
-- Name: phenotype_cvterm_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY phenotype_cvterm
    ADD CONSTRAINT phenotype_cvterm_c1 UNIQUE (phenotype_id, cvterm_id, rank);


--
-- Name: phenotype_cvterm_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY phenotype_cvterm
    ADD CONSTRAINT phenotype_cvterm_pkey PRIMARY KEY (phenotype_cvterm_id);


--
-- Name: phenotype_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY phenotype
    ADD CONSTRAINT phenotype_pkey PRIMARY KEY (phenotype_id);


--
-- Name: phenotypeprop_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY phenotypeprop
    ADD CONSTRAINT phenotypeprop_c1 UNIQUE (phenotype_id, type_id, rank);


--
-- Name: phenotypeprop_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY phenotypeprop
    ADD CONSTRAINT phenotypeprop_pkey PRIMARY KEY (phenotypeprop_id);


--
-- Name: phenstatement_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY phenstatement
    ADD CONSTRAINT phenstatement_c1 UNIQUE (genotype_id, phenotype_id, environment_id, type_id, pub_id);


--
-- Name: phenstatement_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY phenstatement
    ADD CONSTRAINT phenstatement_pkey PRIMARY KEY (phenstatement_id);


--
-- Name: project_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY project
    ADD CONSTRAINT project_c1 UNIQUE (name);


--
-- Name: project_contact_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY project_contact
    ADD CONSTRAINT project_contact_c1 UNIQUE (project_id, contact_id);


--
-- Name: project_contact_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY project_contact
    ADD CONSTRAINT project_contact_pkey PRIMARY KEY (project_contact_id);


--
-- Name: project_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY project
    ADD CONSTRAINT project_pkey PRIMARY KEY (project_id);


--
-- Name: project_pub_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY project_pub
    ADD CONSTRAINT project_pub_c1 UNIQUE (project_id, pub_id);


--
-- Name: project_pub_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY project_pub
    ADD CONSTRAINT project_pub_pkey PRIMARY KEY (project_pub_id);


--
-- Name: project_relationship_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY project_relationship
    ADD CONSTRAINT project_relationship_c1 UNIQUE (subject_project_id, object_project_id, type_id);


--
-- Name: project_relationship_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY project_relationship
    ADD CONSTRAINT project_relationship_pkey PRIMARY KEY (project_relationship_id);


--
-- Name: projectprop_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY projectprop
    ADD CONSTRAINT projectprop_c1 UNIQUE (project_id, type_id, rank);


--
-- Name: projectprop_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY projectprop
    ADD CONSTRAINT projectprop_pkey PRIMARY KEY (projectprop_id);


--
-- Name: pub_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pub
    ADD CONSTRAINT pub_c1 UNIQUE (uniquename);


--
-- Name: pub_dbxref_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pub_dbxref
    ADD CONSTRAINT pub_dbxref_c1 UNIQUE (pub_id, dbxref_id);


--
-- Name: pub_dbxref_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pub_dbxref
    ADD CONSTRAINT pub_dbxref_pkey PRIMARY KEY (pub_dbxref_id);


--
-- Name: pub_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pub
    ADD CONSTRAINT pub_pkey PRIMARY KEY (pub_id);


--
-- Name: pub_relationship_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pub_relationship
    ADD CONSTRAINT pub_relationship_c1 UNIQUE (subject_id, object_id, type_id);


--
-- Name: pub_relationship_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pub_relationship
    ADD CONSTRAINT pub_relationship_pkey PRIMARY KEY (pub_relationship_id);


--
-- Name: pubauthor_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pubauthor
    ADD CONSTRAINT pubauthor_c1 UNIQUE (pub_id, rank);


--
-- Name: pubauthor_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pubauthor
    ADD CONSTRAINT pubauthor_pkey PRIMARY KEY (pubauthor_id);


--
-- Name: pubprop_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pubprop
    ADD CONSTRAINT pubprop_c1 UNIQUE (pub_id, type_id, rank);


--
-- Name: pubprop_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pubprop
    ADD CONSTRAINT pubprop_pkey PRIMARY KEY (pubprop_id);


--
-- Name: stock_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stock
    ADD CONSTRAINT stock_c1 UNIQUE (organism_id, uniquename, type_id);


--
-- Name: stock_cvterm_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stock_cvterm
    ADD CONSTRAINT stock_cvterm_c1 UNIQUE (stock_id, cvterm_id, pub_id, rank);


--
-- Name: stock_cvterm_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stock_cvterm
    ADD CONSTRAINT stock_cvterm_pkey PRIMARY KEY (stock_cvterm_id);


--
-- Name: stock_cvtermprop_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stock_cvtermprop
    ADD CONSTRAINT stock_cvtermprop_c1 UNIQUE (stock_cvterm_id, type_id, rank);


--
-- Name: stock_cvtermprop_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stock_cvtermprop
    ADD CONSTRAINT stock_cvtermprop_pkey PRIMARY KEY (stock_cvtermprop_id);


--
-- Name: stock_dbxref_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stock_dbxref
    ADD CONSTRAINT stock_dbxref_c1 UNIQUE (stock_id, dbxref_id);


--
-- Name: stock_dbxref_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stock_dbxref
    ADD CONSTRAINT stock_dbxref_pkey PRIMARY KEY (stock_dbxref_id);


--
-- Name: stock_dbxrefprop_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stock_dbxrefprop
    ADD CONSTRAINT stock_dbxrefprop_c1 UNIQUE (stock_dbxref_id, type_id, rank);


--
-- Name: stock_dbxrefprop_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stock_dbxrefprop
    ADD CONSTRAINT stock_dbxrefprop_pkey PRIMARY KEY (stock_dbxrefprop_id);


--
-- Name: stock_genotype_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stock_genotype
    ADD CONSTRAINT stock_genotype_c1 UNIQUE (stock_id, genotype_id);


--
-- Name: stock_genotype_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stock_genotype
    ADD CONSTRAINT stock_genotype_pkey PRIMARY KEY (stock_genotype_id);


--
-- Name: stock_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stock
    ADD CONSTRAINT stock_pkey PRIMARY KEY (stock_id);


--
-- Name: stock_pub_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stock_pub
    ADD CONSTRAINT stock_pub_c1 UNIQUE (stock_id, pub_id);


--
-- Name: stock_pub_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stock_pub
    ADD CONSTRAINT stock_pub_pkey PRIMARY KEY (stock_pub_id);


--
-- Name: stock_relationship_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stock_relationship
    ADD CONSTRAINT stock_relationship_c1 UNIQUE (subject_id, object_id, type_id, rank);


--
-- Name: stock_relationship_cvterm_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stock_relationship_cvterm
    ADD CONSTRAINT stock_relationship_cvterm_pkey PRIMARY KEY (stock_relationship_cvterm_id);


--
-- Name: stock_relationship_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stock_relationship
    ADD CONSTRAINT stock_relationship_pkey PRIMARY KEY (stock_relationship_id);


--
-- Name: stock_relationship_pub_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stock_relationship_pub
    ADD CONSTRAINT stock_relationship_pub_c1 UNIQUE (stock_relationship_id, pub_id);


--
-- Name: stock_relationship_pub_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stock_relationship_pub
    ADD CONSTRAINT stock_relationship_pub_pkey PRIMARY KEY (stock_relationship_pub_id);


--
-- Name: stockcollection_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stockcollection
    ADD CONSTRAINT stockcollection_c1 UNIQUE (uniquename, type_id);


--
-- Name: stockcollection_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stockcollection
    ADD CONSTRAINT stockcollection_pkey PRIMARY KEY (stockcollection_id);


--
-- Name: stockcollection_stock_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stockcollection_stock
    ADD CONSTRAINT stockcollection_stock_c1 UNIQUE (stockcollection_id, stock_id);


--
-- Name: stockcollection_stock_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stockcollection_stock
    ADD CONSTRAINT stockcollection_stock_pkey PRIMARY KEY (stockcollection_stock_id);


--
-- Name: stockcollectionprop_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stockcollectionprop
    ADD CONSTRAINT stockcollectionprop_c1 UNIQUE (stockcollection_id, type_id, rank);


--
-- Name: stockcollectionprop_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stockcollectionprop
    ADD CONSTRAINT stockcollectionprop_pkey PRIMARY KEY (stockcollectionprop_id);


--
-- Name: stockprop_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stockprop
    ADD CONSTRAINT stockprop_c1 UNIQUE (stock_id, type_id, rank);


--
-- Name: stockprop_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stockprop
    ADD CONSTRAINT stockprop_pkey PRIMARY KEY (stockprop_id);


--
-- Name: stockprop_pub_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stockprop_pub
    ADD CONSTRAINT stockprop_pub_c1 UNIQUE (stockprop_id, pub_id);


--
-- Name: stockprop_pub_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY stockprop_pub
    ADD CONSTRAINT stockprop_pub_pkey PRIMARY KEY (stockprop_pub_id);


--
-- Name: synonym_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY synonym
    ADD CONSTRAINT synonym_c1 UNIQUE (name, type_id);


--
-- Name: synonym_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY synonym
    ADD CONSTRAINT synonym_pkey PRIMARY KEY (synonym_id);


--
-- Name: tableinfo_c1; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY tableinfo
    ADD CONSTRAINT tableinfo_c1 UNIQUE (name);


--
-- Name: tableinfo_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY tableinfo
    ADD CONSTRAINT tableinfo_pkey PRIMARY KEY (tableinfo_id);


--
-- Name: contact_relationship_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX contact_relationship_idx1 ON contact_relationship USING btree (type_id);


--
-- Name: contact_relationship_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX contact_relationship_idx2 ON contact_relationship USING btree (subject_id);


--
-- Name: contact_relationship_idx3; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX contact_relationship_idx3 ON contact_relationship USING btree (object_id);


--
-- Name: INDEX cvterm_c2; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON INDEX cvterm_c2 IS 'The OBO identifier is globally unique.';


--
-- Name: cvterm_dbxref_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX cvterm_dbxref_idx1 ON cvterm_dbxref USING btree (cvterm_id);


--
-- Name: cvterm_dbxref_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX cvterm_dbxref_idx2 ON cvterm_dbxref USING btree (dbxref_id);


--
-- Name: cvterm_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX cvterm_idx1 ON cvterm USING btree (cv_id);


--
-- Name: cvterm_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX cvterm_idx2 ON cvterm USING btree (name);


--
-- Name: cvterm_idx3; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX cvterm_idx3 ON cvterm USING btree (dbxref_id);


--
-- Name: cvterm_relationship_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX cvterm_relationship_idx1 ON cvterm_relationship USING btree (type_id);


--
-- Name: cvterm_relationship_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX cvterm_relationship_idx2 ON cvterm_relationship USING btree (subject_id);


--
-- Name: cvterm_relationship_idx3; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX cvterm_relationship_idx3 ON cvterm_relationship USING btree (object_id);


--
-- Name: cvtermpath_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX cvtermpath_idx1 ON cvtermpath USING btree (type_id);


--
-- Name: cvtermpath_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX cvtermpath_idx2 ON cvtermpath USING btree (subject_id);


--
-- Name: cvtermpath_idx3; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX cvtermpath_idx3 ON cvtermpath USING btree (object_id);


--
-- Name: cvtermpath_idx4; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX cvtermpath_idx4 ON cvtermpath USING btree (cv_id);


--
-- Name: cvtermprop_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX cvtermprop_idx1 ON cvtermprop USING btree (cvterm_id);


--
-- Name: cvtermprop_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX cvtermprop_idx2 ON cvtermprop USING btree (type_id);


--
-- Name: cvtermsynonym_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX cvtermsynonym_idx1 ON cvtermsynonym USING btree (cvterm_id);


--
-- Name: dbxref_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX dbxref_idx1 ON dbxref USING btree (db_id);


--
-- Name: dbxref_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX dbxref_idx2 ON dbxref USING btree (accession);


--
-- Name: dbxref_idx3; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX dbxref_idx3 ON dbxref USING btree (version);


--
-- Name: dbxrefprop_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX dbxrefprop_idx1 ON dbxrefprop USING btree (dbxref_id);


--
-- Name: dbxrefprop_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX dbxrefprop_idx2 ON dbxrefprop USING btree (type_id);


--
-- Name: environment_cvterm_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX environment_cvterm_idx1 ON environment_cvterm USING btree (environment_id);


--
-- Name: environment_cvterm_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX environment_cvterm_idx2 ON environment_cvterm USING btree (cvterm_id);


--
-- Name: environment_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX environment_idx1 ON environment USING btree (uniquename);


--
-- Name: feature_cvterm_dbxref_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_cvterm_dbxref_idx1 ON feature_cvterm_dbxref USING btree (feature_cvterm_id);


--
-- Name: feature_cvterm_dbxref_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_cvterm_dbxref_idx2 ON feature_cvterm_dbxref USING btree (dbxref_id);


--
-- Name: feature_cvterm_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_cvterm_idx1 ON feature_cvterm USING btree (feature_id);


--
-- Name: feature_cvterm_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_cvterm_idx2 ON feature_cvterm USING btree (cvterm_id);


--
-- Name: feature_cvterm_idx3; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_cvterm_idx3 ON feature_cvterm USING btree (pub_id);


--
-- Name: feature_cvterm_pub_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_cvterm_pub_idx1 ON feature_cvterm_pub USING btree (feature_cvterm_id);


--
-- Name: feature_cvterm_pub_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_cvterm_pub_idx2 ON feature_cvterm_pub USING btree (pub_id);


--
-- Name: feature_cvtermprop_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_cvtermprop_idx1 ON feature_cvtermprop USING btree (feature_cvterm_id);


--
-- Name: feature_cvtermprop_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_cvtermprop_idx2 ON feature_cvtermprop USING btree (type_id);


--
-- Name: feature_dbxref_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_dbxref_idx1 ON feature_dbxref USING btree (feature_id);


--
-- Name: feature_dbxref_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_dbxref_idx2 ON feature_dbxref USING btree (dbxref_id);


--
-- Name: feature_genotype_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_genotype_idx1 ON feature_genotype USING btree (feature_id);


--
-- Name: feature_genotype_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_genotype_idx2 ON feature_genotype USING btree (genotype_id);


--
-- Name: feature_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_idx1 ON feature USING btree (dbxref_id);


--
-- Name: feature_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_idx2 ON feature USING btree (organism_id);


--
-- Name: feature_idx3; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_idx3 ON feature USING btree (type_id);


--
-- Name: feature_idx4; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_idx4 ON feature USING btree (uniquename);


--
-- Name: feature_idx5; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_idx5 ON feature USING btree (lower((name)::text));


--
-- Name: feature_name_ind1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_name_ind1 ON feature USING btree (name);


--
-- Name: feature_phenotype_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_phenotype_idx1 ON feature_phenotype USING btree (feature_id);


--
-- Name: feature_phenotype_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_phenotype_idx2 ON feature_phenotype USING btree (phenotype_id);


--
-- Name: feature_pub_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_pub_idx1 ON feature_pub USING btree (feature_id);


--
-- Name: feature_pub_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_pub_idx2 ON feature_pub USING btree (pub_id);


--
-- Name: feature_pubprop_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_pubprop_idx1 ON feature_pubprop USING btree (feature_pub_id);


--
-- Name: feature_relationship_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_relationship_idx1 ON feature_relationship USING btree (subject_id);


--
-- Name: feature_relationship_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_relationship_idx2 ON feature_relationship USING btree (object_id);


--
-- Name: feature_relationship_idx3; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_relationship_idx3 ON feature_relationship USING btree (type_id);


--
-- Name: feature_relationship_pub_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_relationship_pub_idx1 ON feature_relationship_pub USING btree (feature_relationship_id);


--
-- Name: feature_relationship_pub_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_relationship_pub_idx2 ON feature_relationship_pub USING btree (pub_id);


--
-- Name: feature_relationshipprop_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_relationshipprop_idx1 ON feature_relationshipprop USING btree (feature_relationship_id);


--
-- Name: feature_relationshipprop_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_relationshipprop_idx2 ON feature_relationshipprop USING btree (type_id);


--
-- Name: feature_relationshipprop_pub_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_relationshipprop_pub_idx1 ON feature_relationshipprop_pub USING btree (feature_relationshipprop_id);


--
-- Name: feature_relationshipprop_pub_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_relationshipprop_pub_idx2 ON feature_relationshipprop_pub USING btree (pub_id);


--
-- Name: feature_synonym_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_synonym_idx1 ON feature_synonym USING btree (synonym_id);


--
-- Name: feature_synonym_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_synonym_idx2 ON feature_synonym USING btree (feature_id);


--
-- Name: feature_synonym_idx3; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX feature_synonym_idx3 ON feature_synonym USING btree (pub_id);


--
-- Name: featureloc_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX featureloc_idx1 ON featureloc USING btree (feature_id);


--
-- Name: featureloc_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX featureloc_idx2 ON featureloc USING btree (srcfeature_id);


--
-- Name: featureloc_idx3; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX featureloc_idx3 ON featureloc USING btree (srcfeature_id, fmin, fmax);


--
-- Name: featureloc_pub_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX featureloc_pub_idx1 ON featureloc_pub USING btree (featureloc_id);


--
-- Name: featureloc_pub_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX featureloc_pub_idx2 ON featureloc_pub USING btree (pub_id);


--
-- Name: INDEX featureprop_c1; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON INDEX featureprop_c1 IS 'For any one feature, multivalued
property-value pairs must be differentiated by rank.';


--
-- Name: featureprop_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX featureprop_idx1 ON featureprop USING btree (feature_id);


--
-- Name: featureprop_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX featureprop_idx2 ON featureprop USING btree (type_id);


--
-- Name: featureprop_pub_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX featureprop_pub_idx1 ON featureprop_pub USING btree (featureprop_id);


--
-- Name: featureprop_pub_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX featureprop_pub_idx2 ON featureprop_pub USING btree (pub_id);


--
-- Name: genotype_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX genotype_idx1 ON genotype USING btree (uniquename);


--
-- Name: genotype_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX genotype_idx2 ON genotype USING btree (name);


--
-- Name: genotypeprop_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX genotypeprop_idx1 ON genotypeprop USING btree (genotype_id);


--
-- Name: genotypeprop_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX genotypeprop_idx2 ON genotypeprop USING btree (type_id);


--
-- Name: nd_experiment_project_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX nd_experiment_project_idx1 ON nd_experiment_project USING btree (project_id);


--
-- Name: nd_experiment_project_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX nd_experiment_project_idx2 ON nd_experiment_project USING btree (nd_experiment_id);


--
-- Name: nd_experiment_pub_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX nd_experiment_pub_idx1 ON nd_experiment_pub USING btree (nd_experiment_id);


--
-- Name: nd_experiment_pub_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX nd_experiment_pub_idx2 ON nd_experiment_pub USING btree (pub_id);


--
-- Name: nd_experiment_stock_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX nd_experiment_stock_idx1 ON nd_experiment_stock USING btree (stock_id);


--
-- Name: nd_experiment_stock_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX nd_experiment_stock_idx2 ON nd_experiment_stock USING btree (nd_experiment_id);


--
-- Name: organism_dbxref_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX organism_dbxref_idx1 ON organism_dbxref USING btree (organism_id);


--
-- Name: organism_dbxref_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX organism_dbxref_idx2 ON organism_dbxref USING btree (dbxref_id);


--
-- Name: organismprop_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX organismprop_idx1 ON organismprop USING btree (organism_id);


--
-- Name: organismprop_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX organismprop_idx2 ON organismprop USING btree (type_id);


--
-- Name: phendesc_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX phendesc_idx1 ON phendesc USING btree (genotype_id);


--
-- Name: phendesc_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX phendesc_idx2 ON phendesc USING btree (environment_id);


--
-- Name: phendesc_idx3; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX phendesc_idx3 ON phendesc USING btree (pub_id);


--
-- Name: phenotype_comparison_cvterm_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX phenotype_comparison_cvterm_idx1 ON phenotype_comparison_cvterm USING btree (phenotype_comparison_id);


--
-- Name: phenotype_comparison_cvterm_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX phenotype_comparison_cvterm_idx2 ON phenotype_comparison_cvterm USING btree (cvterm_id);


--
-- Name: phenotype_comparison_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX phenotype_comparison_idx1 ON phenotype_comparison USING btree (genotype1_id);


--
-- Name: phenotype_comparison_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX phenotype_comparison_idx2 ON phenotype_comparison USING btree (genotype2_id);


--
-- Name: phenotype_comparison_idx4; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX phenotype_comparison_idx4 ON phenotype_comparison USING btree (pub_id);


--
-- Name: phenotype_cvterm_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX phenotype_cvterm_idx1 ON phenotype_cvterm USING btree (phenotype_id);


--
-- Name: phenotype_cvterm_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX phenotype_cvterm_idx2 ON phenotype_cvterm USING btree (cvterm_id);


--
-- Name: phenotype_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX phenotype_idx1 ON phenotype USING btree (cvalue_id);


--
-- Name: phenotype_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX phenotype_idx2 ON phenotype USING btree (observable_id);


--
-- Name: phenotype_idx3; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX phenotype_idx3 ON phenotype USING btree (attr_id);


--
-- Name: phenotypeprop_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX phenotypeprop_idx1 ON phenotypeprop USING btree (phenotype_id);


--
-- Name: phenotypeprop_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX phenotypeprop_idx2 ON phenotypeprop USING btree (type_id);


--
-- Name: phenstatement_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX phenstatement_idx1 ON phenstatement USING btree (genotype_id);


--
-- Name: phenstatement_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX phenstatement_idx2 ON phenstatement USING btree (phenotype_id);


--
-- Name: project_contact_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX project_contact_idx1 ON project_contact USING btree (project_id);


--
-- Name: project_contact_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX project_contact_idx2 ON project_contact USING btree (contact_id);


--
-- Name: project_pub_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX project_pub_idx1 ON project_pub USING btree (project_id);


--
-- Name: project_pub_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX project_pub_idx2 ON project_pub USING btree (pub_id);


--
-- Name: pub_dbxref_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX pub_dbxref_idx1 ON pub_dbxref USING btree (pub_id);


--
-- Name: pub_dbxref_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX pub_dbxref_idx2 ON pub_dbxref USING btree (dbxref_id);


--
-- Name: pub_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX pub_idx1 ON pub USING btree (type_id);


--
-- Name: pub_relationship_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX pub_relationship_idx1 ON pub_relationship USING btree (subject_id);


--
-- Name: pub_relationship_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX pub_relationship_idx2 ON pub_relationship USING btree (object_id);


--
-- Name: pub_relationship_idx3; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX pub_relationship_idx3 ON pub_relationship USING btree (type_id);


--
-- Name: pubauthor_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX pubauthor_idx2 ON pubauthor USING btree (pub_id);


--
-- Name: pubprop_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX pubprop_idx1 ON pubprop USING btree (pub_id);


--
-- Name: pubprop_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX pubprop_idx2 ON pubprop USING btree (type_id);


--
-- Name: stock_cvterm_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stock_cvterm_idx1 ON stock_cvterm USING btree (stock_id);


--
-- Name: stock_cvterm_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stock_cvterm_idx2 ON stock_cvterm USING btree (cvterm_id);


--
-- Name: stock_cvterm_idx3; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stock_cvterm_idx3 ON stock_cvterm USING btree (pub_id);


--
-- Name: stock_cvtermprop_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stock_cvtermprop_idx1 ON stock_cvtermprop USING btree (stock_cvterm_id);


--
-- Name: stock_cvtermprop_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stock_cvtermprop_idx2 ON stock_cvtermprop USING btree (type_id);


--
-- Name: stock_dbxref_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stock_dbxref_idx1 ON stock_dbxref USING btree (stock_id);


--
-- Name: stock_dbxref_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stock_dbxref_idx2 ON stock_dbxref USING btree (dbxref_id);


--
-- Name: stock_dbxrefprop_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stock_dbxrefprop_idx1 ON stock_dbxrefprop USING btree (stock_dbxref_id);


--
-- Name: stock_dbxrefprop_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stock_dbxrefprop_idx2 ON stock_dbxrefprop USING btree (type_id);


--
-- Name: stock_genotype_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stock_genotype_idx1 ON stock_genotype USING btree (stock_id);


--
-- Name: stock_genotype_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stock_genotype_idx2 ON stock_genotype USING btree (genotype_id);


--
-- Name: stock_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stock_idx1 ON stock USING btree (dbxref_id);


--
-- Name: stock_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stock_idx2 ON stock USING btree (organism_id);


--
-- Name: stock_idx3; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stock_idx3 ON stock USING btree (type_id);


--
-- Name: stock_idx4; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stock_idx4 ON stock USING btree (uniquename);


--
-- Name: stock_name_ind1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stock_name_ind1 ON stock USING btree (name);


--
-- Name: stock_pub_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stock_pub_idx1 ON stock_pub USING btree (stock_id);


--
-- Name: stock_pub_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stock_pub_idx2 ON stock_pub USING btree (pub_id);


--
-- Name: stock_relationship_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stock_relationship_idx1 ON stock_relationship USING btree (subject_id);


--
-- Name: stock_relationship_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stock_relationship_idx2 ON stock_relationship USING btree (object_id);


--
-- Name: stock_relationship_idx3; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stock_relationship_idx3 ON stock_relationship USING btree (type_id);


--
-- Name: stock_relationship_pub_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stock_relationship_pub_idx1 ON stock_relationship_pub USING btree (stock_relationship_id);


--
-- Name: stock_relationship_pub_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stock_relationship_pub_idx2 ON stock_relationship_pub USING btree (pub_id);


--
-- Name: stockcollection_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stockcollection_idx1 ON stockcollection USING btree (contact_id);


--
-- Name: stockcollection_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stockcollection_idx2 ON stockcollection USING btree (type_id);


--
-- Name: stockcollection_idx3; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stockcollection_idx3 ON stockcollection USING btree (uniquename);


--
-- Name: stockcollection_name_ind1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stockcollection_name_ind1 ON stockcollection USING btree (name);


--
-- Name: stockcollection_stock_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stockcollection_stock_idx1 ON stockcollection_stock USING btree (stockcollection_id);


--
-- Name: stockcollection_stock_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stockcollection_stock_idx2 ON stockcollection_stock USING btree (stock_id);


--
-- Name: stockcollectionprop_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stockcollectionprop_idx1 ON stockcollectionprop USING btree (stockcollection_id);


--
-- Name: stockcollectionprop_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stockcollectionprop_idx2 ON stockcollectionprop USING btree (type_id);


--
-- Name: stockprop_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stockprop_idx1 ON stockprop USING btree (stock_id);


--
-- Name: stockprop_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stockprop_idx2 ON stockprop USING btree (type_id);


--
-- Name: stockprop_pub_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stockprop_pub_idx1 ON stockprop_pub USING btree (stockprop_id);


--
-- Name: stockprop_pub_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX stockprop_pub_idx2 ON stockprop_pub USING btree (pub_id);


--
-- Name: synonym_idx1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX synonym_idx1 ON synonym USING btree (type_id);


--
-- Name: synonym_idx2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX synonym_idx2 ON synonym USING btree (lower((synonym_sgml)::text));


--
-- Name: chadoprop_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY chadoprop
    ADD CONSTRAINT chadoprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contact_relationship_object_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY contact_relationship
    ADD CONSTRAINT contact_relationship_object_id_fkey FOREIGN KEY (object_id) REFERENCES contact(contact_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contact_relationship_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY contact_relationship
    ADD CONSTRAINT contact_relationship_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES contact(contact_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contact_relationship_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY contact_relationship
    ADD CONSTRAINT contact_relationship_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contact_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY contact
    ADD CONSTRAINT contact_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id);


--
-- Name: cvprop_cv_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cvprop
    ADD CONSTRAINT cvprop_cv_id_fkey FOREIGN KEY (cv_id) REFERENCES cv(cv_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvprop_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cvprop
    ADD CONSTRAINT cvprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvterm_cv_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cvterm
    ADD CONSTRAINT cvterm_cv_id_fkey FOREIGN KEY (cv_id) REFERENCES cv(cv_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvterm_dbxref_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cvterm_dbxref
    ADD CONSTRAINT cvterm_dbxref_cvterm_id_fkey FOREIGN KEY (cvterm_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvterm_dbxref_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cvterm_dbxref
    ADD CONSTRAINT cvterm_dbxref_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvterm_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cvterm
    ADD CONSTRAINT cvterm_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvterm_relationship_object_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cvterm_relationship
    ADD CONSTRAINT cvterm_relationship_object_id_fkey FOREIGN KEY (object_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvterm_relationship_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cvterm_relationship
    ADD CONSTRAINT cvterm_relationship_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvterm_relationship_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cvterm_relationship
    ADD CONSTRAINT cvterm_relationship_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvtermpath_cv_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cvtermpath
    ADD CONSTRAINT cvtermpath_cv_id_fkey FOREIGN KEY (cv_id) REFERENCES cv(cv_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvtermpath_object_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cvtermpath
    ADD CONSTRAINT cvtermpath_object_id_fkey FOREIGN KEY (object_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvtermpath_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cvtermpath
    ADD CONSTRAINT cvtermpath_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvtermpath_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cvtermpath
    ADD CONSTRAINT cvtermpath_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvtermprop_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cvtermprop
    ADD CONSTRAINT cvtermprop_cvterm_id_fkey FOREIGN KEY (cvterm_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: cvtermprop_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cvtermprop
    ADD CONSTRAINT cvtermprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: cvtermsynonym_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cvtermsynonym
    ADD CONSTRAINT cvtermsynonym_cvterm_id_fkey FOREIGN KEY (cvterm_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvtermsynonym_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cvtermsynonym
    ADD CONSTRAINT cvtermsynonym_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: dbxref_db_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY dbxref
    ADD CONSTRAINT dbxref_db_id_fkey FOREIGN KEY (db_id) REFERENCES db(db_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: dbxrefprop_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY dbxrefprop
    ADD CONSTRAINT dbxrefprop_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: dbxrefprop_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY dbxrefprop
    ADD CONSTRAINT dbxrefprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: environment_cvterm_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY environment_cvterm
    ADD CONSTRAINT environment_cvterm_cvterm_id_fkey FOREIGN KEY (cvterm_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: environment_cvterm_environment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY environment_cvterm
    ADD CONSTRAINT environment_cvterm_environment_id_fkey FOREIGN KEY (environment_id) REFERENCES environment(environment_id) ON DELETE CASCADE;


--
-- Name: feature_cvterm_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_cvterm
    ADD CONSTRAINT feature_cvterm_cvterm_id_fkey FOREIGN KEY (cvterm_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_cvterm_dbxref_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_cvterm_dbxref
    ADD CONSTRAINT feature_cvterm_dbxref_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_cvterm_dbxref_feature_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_cvterm_dbxref
    ADD CONSTRAINT feature_cvterm_dbxref_feature_cvterm_id_fkey FOREIGN KEY (feature_cvterm_id) REFERENCES feature_cvterm(feature_cvterm_id) ON DELETE CASCADE;


--
-- Name: feature_cvterm_feature_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_cvterm
    ADD CONSTRAINT feature_cvterm_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_cvterm_pub_feature_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_cvterm_pub
    ADD CONSTRAINT feature_cvterm_pub_feature_cvterm_id_fkey FOREIGN KEY (feature_cvterm_id) REFERENCES feature_cvterm(feature_cvterm_id) ON DELETE CASCADE;


--
-- Name: feature_cvterm_pub_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_cvterm
    ADD CONSTRAINT feature_cvterm_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_cvterm_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_cvterm_pub
    ADD CONSTRAINT feature_cvterm_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_cvtermprop_feature_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_cvtermprop
    ADD CONSTRAINT feature_cvtermprop_feature_cvterm_id_fkey FOREIGN KEY (feature_cvterm_id) REFERENCES feature_cvterm(feature_cvterm_id) ON DELETE CASCADE;


--
-- Name: feature_cvtermprop_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_cvtermprop
    ADD CONSTRAINT feature_cvtermprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_dbxref_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_dbxref
    ADD CONSTRAINT feature_dbxref_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_dbxref_feature_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_dbxref
    ADD CONSTRAINT feature_dbxref_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature
    ADD CONSTRAINT feature_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_genotype_chromosome_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_genotype
    ADD CONSTRAINT feature_genotype_chromosome_id_fkey FOREIGN KEY (chromosome_id) REFERENCES feature(feature_id) ON DELETE SET NULL;


--
-- Name: feature_genotype_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_genotype
    ADD CONSTRAINT feature_genotype_cvterm_id_fkey FOREIGN KEY (cvterm_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: feature_genotype_feature_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_genotype
    ADD CONSTRAINT feature_genotype_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES feature(feature_id) ON DELETE CASCADE;


--
-- Name: feature_genotype_genotype_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_genotype
    ADD CONSTRAINT feature_genotype_genotype_id_fkey FOREIGN KEY (genotype_id) REFERENCES genotype(genotype_id) ON DELETE CASCADE;


--
-- Name: feature_organism_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature
    ADD CONSTRAINT feature_organism_id_fkey FOREIGN KEY (organism_id) REFERENCES organism(organism_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_phenotype_feature_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_phenotype
    ADD CONSTRAINT feature_phenotype_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES feature(feature_id) ON DELETE CASCADE;


--
-- Name: feature_phenotype_phenotype_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_phenotype
    ADD CONSTRAINT feature_phenotype_phenotype_id_fkey FOREIGN KEY (phenotype_id) REFERENCES phenotype(phenotype_id) ON DELETE CASCADE;


--
-- Name: feature_pub_feature_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_pub
    ADD CONSTRAINT feature_pub_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_pub
    ADD CONSTRAINT feature_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_pubprop_feature_pub_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_pubprop
    ADD CONSTRAINT feature_pubprop_feature_pub_id_fkey FOREIGN KEY (feature_pub_id) REFERENCES feature_pub(feature_pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_pubprop_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_pubprop
    ADD CONSTRAINT feature_pubprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_relationship_object_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_relationship
    ADD CONSTRAINT feature_relationship_object_id_fkey FOREIGN KEY (object_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_relationship_pub_feature_relationship_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_relationship_pub
    ADD CONSTRAINT feature_relationship_pub_feature_relationship_id_fkey FOREIGN KEY (feature_relationship_id) REFERENCES feature_relationship(feature_relationship_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_relationship_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_relationship_pub
    ADD CONSTRAINT feature_relationship_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_relationship_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_relationship
    ADD CONSTRAINT feature_relationship_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_relationship_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_relationship
    ADD CONSTRAINT feature_relationship_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_relationshipprop_feature_relationship_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_relationshipprop
    ADD CONSTRAINT feature_relationshipprop_feature_relationship_id_fkey FOREIGN KEY (feature_relationship_id) REFERENCES feature_relationship(feature_relationship_id) ON DELETE CASCADE;


--
-- Name: feature_relationshipprop_pub_feature_relationshipprop_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_relationshipprop_pub
    ADD CONSTRAINT feature_relationshipprop_pub_feature_relationshipprop_id_fkey FOREIGN KEY (feature_relationshipprop_id) REFERENCES feature_relationshipprop(feature_relationshipprop_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_relationshipprop_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_relationshipprop_pub
    ADD CONSTRAINT feature_relationshipprop_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_relationshipprop_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_relationshipprop
    ADD CONSTRAINT feature_relationshipprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_synonym_feature_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_synonym
    ADD CONSTRAINT feature_synonym_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_synonym_pub_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_synonym
    ADD CONSTRAINT feature_synonym_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_synonym_synonym_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature_synonym
    ADD CONSTRAINT feature_synonym_synonym_id_fkey FOREIGN KEY (synonym_id) REFERENCES synonym(synonym_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feature
    ADD CONSTRAINT feature_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featureloc_feature_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY featureloc
    ADD CONSTRAINT featureloc_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featureloc_pub_featureloc_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY featureloc_pub
    ADD CONSTRAINT featureloc_pub_featureloc_id_fkey FOREIGN KEY (featureloc_id) REFERENCES featureloc(featureloc_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featureloc_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY featureloc_pub
    ADD CONSTRAINT featureloc_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featureloc_srcfeature_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY featureloc
    ADD CONSTRAINT featureloc_srcfeature_id_fkey FOREIGN KEY (srcfeature_id) REFERENCES feature(feature_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featureprop_feature_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY featureprop
    ADD CONSTRAINT featureprop_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featureprop_pub_featureprop_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY featureprop_pub
    ADD CONSTRAINT featureprop_pub_featureprop_id_fkey FOREIGN KEY (featureprop_id) REFERENCES featureprop(featureprop_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featureprop_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY featureprop_pub
    ADD CONSTRAINT featureprop_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featureprop_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY featureprop
    ADD CONSTRAINT featureprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: genotype_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY genotype
    ADD CONSTRAINT genotype_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: genotypeprop_genotype_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY genotypeprop
    ADD CONSTRAINT genotypeprop_genotype_id_fkey FOREIGN KEY (genotype_id) REFERENCES genotype(genotype_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: genotypeprop_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY genotypeprop
    ADD CONSTRAINT genotypeprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_contact_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_experiment_contact
    ADD CONSTRAINT nd_experiment_contact_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES contact(contact_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_contact_nd_experiment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_experiment_contact
    ADD CONSTRAINT nd_experiment_contact_nd_experiment_id_fkey FOREIGN KEY (nd_experiment_id) REFERENCES nd_experiment(nd_experiment_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_dbxref_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_experiment_dbxref
    ADD CONSTRAINT nd_experiment_dbxref_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_dbxref_nd_experiment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_experiment_dbxref
    ADD CONSTRAINT nd_experiment_dbxref_nd_experiment_id_fkey FOREIGN KEY (nd_experiment_id) REFERENCES nd_experiment(nd_experiment_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_genotype_genotype_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_experiment_genotype
    ADD CONSTRAINT nd_experiment_genotype_genotype_id_fkey FOREIGN KEY (genotype_id) REFERENCES genotype(genotype_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_genotype_nd_experiment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_experiment_genotype
    ADD CONSTRAINT nd_experiment_genotype_nd_experiment_id_fkey FOREIGN KEY (nd_experiment_id) REFERENCES nd_experiment(nd_experiment_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_nd_geolocation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_experiment
    ADD CONSTRAINT nd_experiment_nd_geolocation_id_fkey FOREIGN KEY (nd_geolocation_id) REFERENCES nd_geolocation(nd_geolocation_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_phenotype_nd_experiment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_experiment_phenotype
    ADD CONSTRAINT nd_experiment_phenotype_nd_experiment_id_fkey FOREIGN KEY (nd_experiment_id) REFERENCES nd_experiment(nd_experiment_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_phenotype_phenotype_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_experiment_phenotype
    ADD CONSTRAINT nd_experiment_phenotype_phenotype_id_fkey FOREIGN KEY (phenotype_id) REFERENCES phenotype(phenotype_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_project_nd_experiment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_experiment_project
    ADD CONSTRAINT nd_experiment_project_nd_experiment_id_fkey FOREIGN KEY (nd_experiment_id) REFERENCES nd_experiment(nd_experiment_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_project_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_experiment_project
    ADD CONSTRAINT nd_experiment_project_project_id_fkey FOREIGN KEY (project_id) REFERENCES project(project_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_protocol_nd_experiment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_experiment_protocol
    ADD CONSTRAINT nd_experiment_protocol_nd_experiment_id_fkey FOREIGN KEY (nd_experiment_id) REFERENCES nd_experiment(nd_experiment_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_protocol_nd_protocol_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_experiment_protocol
    ADD CONSTRAINT nd_experiment_protocol_nd_protocol_id_fkey FOREIGN KEY (nd_protocol_id) REFERENCES nd_protocol(nd_protocol_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_pub_nd_experiment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_experiment_pub
    ADD CONSTRAINT nd_experiment_pub_nd_experiment_id_fkey FOREIGN KEY (nd_experiment_id) REFERENCES nd_experiment(nd_experiment_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_experiment_pub
    ADD CONSTRAINT nd_experiment_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_stock_dbxref_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_experiment_stock_dbxref
    ADD CONSTRAINT nd_experiment_stock_dbxref_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_stock_dbxref_nd_experiment_stock_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_experiment_stock_dbxref
    ADD CONSTRAINT nd_experiment_stock_dbxref_nd_experiment_stock_id_fkey FOREIGN KEY (nd_experiment_stock_id) REFERENCES nd_experiment_stock(nd_experiment_stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_stock_nd_experiment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_experiment_stock
    ADD CONSTRAINT nd_experiment_stock_nd_experiment_id_fkey FOREIGN KEY (nd_experiment_id) REFERENCES nd_experiment(nd_experiment_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_stock_stock_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_experiment_stock
    ADD CONSTRAINT nd_experiment_stock_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES stock(stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_stock_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_experiment_stock
    ADD CONSTRAINT nd_experiment_stock_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_stockprop_nd_experiment_stock_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_experiment_stockprop
    ADD CONSTRAINT nd_experiment_stockprop_nd_experiment_stock_id_fkey FOREIGN KEY (nd_experiment_stock_id) REFERENCES nd_experiment_stock(nd_experiment_stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_stockprop_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_experiment_stockprop
    ADD CONSTRAINT nd_experiment_stockprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_experiment
    ADD CONSTRAINT nd_experiment_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experimentprop_nd_experiment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_experimentprop
    ADD CONSTRAINT nd_experimentprop_nd_experiment_id_fkey FOREIGN KEY (nd_experiment_id) REFERENCES nd_experiment(nd_experiment_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experimentprop_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_experimentprop
    ADD CONSTRAINT nd_experimentprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_geolocationprop_nd_geolocation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_geolocationprop
    ADD CONSTRAINT nd_geolocationprop_nd_geolocation_id_fkey FOREIGN KEY (nd_geolocation_id) REFERENCES nd_geolocation(nd_geolocation_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_geolocationprop_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_geolocationprop
    ADD CONSTRAINT nd_geolocationprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_protocol_reagent_nd_protocol_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_protocol_reagent
    ADD CONSTRAINT nd_protocol_reagent_nd_protocol_id_fkey FOREIGN KEY (nd_protocol_id) REFERENCES nd_protocol(nd_protocol_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_protocol_reagent_reagent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_protocol_reagent
    ADD CONSTRAINT nd_protocol_reagent_reagent_id_fkey FOREIGN KEY (reagent_id) REFERENCES nd_reagent(nd_reagent_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_protocol_reagent_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_protocol_reagent
    ADD CONSTRAINT nd_protocol_reagent_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_protocol_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_protocol
    ADD CONSTRAINT nd_protocol_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_protocolprop_nd_protocol_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_protocolprop
    ADD CONSTRAINT nd_protocolprop_nd_protocol_id_fkey FOREIGN KEY (nd_protocol_id) REFERENCES nd_protocol(nd_protocol_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_protocolprop_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_protocolprop
    ADD CONSTRAINT nd_protocolprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_reagent_relationship_object_reagent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_reagent_relationship
    ADD CONSTRAINT nd_reagent_relationship_object_reagent_id_fkey FOREIGN KEY (object_reagent_id) REFERENCES nd_reagent(nd_reagent_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_reagent_relationship_subject_reagent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_reagent_relationship
    ADD CONSTRAINT nd_reagent_relationship_subject_reagent_id_fkey FOREIGN KEY (subject_reagent_id) REFERENCES nd_reagent(nd_reagent_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_reagent_relationship_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_reagent_relationship
    ADD CONSTRAINT nd_reagent_relationship_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_reagent_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_reagent
    ADD CONSTRAINT nd_reagent_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_reagentprop_nd_reagent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_reagentprop
    ADD CONSTRAINT nd_reagentprop_nd_reagent_id_fkey FOREIGN KEY (nd_reagent_id) REFERENCES nd_reagent(nd_reagent_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_reagentprop_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY nd_reagentprop
    ADD CONSTRAINT nd_reagentprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: organism_dbxref_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY organism_dbxref
    ADD CONSTRAINT organism_dbxref_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: organism_dbxref_organism_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY organism_dbxref
    ADD CONSTRAINT organism_dbxref_organism_id_fkey FOREIGN KEY (organism_id) REFERENCES organism(organism_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: organismprop_organism_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY organismprop
    ADD CONSTRAINT organismprop_organism_id_fkey FOREIGN KEY (organism_id) REFERENCES organism(organism_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: organismprop_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY organismprop
    ADD CONSTRAINT organismprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: phendesc_environment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phendesc
    ADD CONSTRAINT phendesc_environment_id_fkey FOREIGN KEY (environment_id) REFERENCES environment(environment_id) ON DELETE CASCADE;


--
-- Name: phendesc_genotype_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phendesc
    ADD CONSTRAINT phendesc_genotype_id_fkey FOREIGN KEY (genotype_id) REFERENCES genotype(genotype_id) ON DELETE CASCADE;


--
-- Name: phendesc_pub_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phendesc
    ADD CONSTRAINT phendesc_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES pub(pub_id) ON DELETE CASCADE;


--
-- Name: phendesc_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phendesc
    ADD CONSTRAINT phendesc_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: phenotype_assay_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phenotype
    ADD CONSTRAINT phenotype_assay_id_fkey FOREIGN KEY (assay_id) REFERENCES cvterm(cvterm_id) ON DELETE SET NULL;


--
-- Name: phenotype_attr_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phenotype
    ADD CONSTRAINT phenotype_attr_id_fkey FOREIGN KEY (attr_id) REFERENCES cvterm(cvterm_id) ON DELETE SET NULL;


--
-- Name: phenotype_comparison_cvterm_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phenotype_comparison_cvterm
    ADD CONSTRAINT phenotype_comparison_cvterm_cvterm_id_fkey FOREIGN KEY (cvterm_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: phenotype_comparison_cvterm_phenotype_comparison_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phenotype_comparison_cvterm
    ADD CONSTRAINT phenotype_comparison_cvterm_phenotype_comparison_id_fkey FOREIGN KEY (phenotype_comparison_id) REFERENCES phenotype_comparison(phenotype_comparison_id) ON DELETE CASCADE;


--
-- Name: phenotype_comparison_cvterm_pub_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phenotype_comparison_cvterm
    ADD CONSTRAINT phenotype_comparison_cvterm_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES pub(pub_id) ON DELETE CASCADE;


--
-- Name: phenotype_comparison_environment1_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phenotype_comparison
    ADD CONSTRAINT phenotype_comparison_environment1_id_fkey FOREIGN KEY (environment1_id) REFERENCES environment(environment_id) ON DELETE CASCADE;


--
-- Name: phenotype_comparison_environment2_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phenotype_comparison
    ADD CONSTRAINT phenotype_comparison_environment2_id_fkey FOREIGN KEY (environment2_id) REFERENCES environment(environment_id) ON DELETE CASCADE;


--
-- Name: phenotype_comparison_genotype1_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phenotype_comparison
    ADD CONSTRAINT phenotype_comparison_genotype1_id_fkey FOREIGN KEY (genotype1_id) REFERENCES genotype(genotype_id) ON DELETE CASCADE;


--
-- Name: phenotype_comparison_genotype2_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phenotype_comparison
    ADD CONSTRAINT phenotype_comparison_genotype2_id_fkey FOREIGN KEY (genotype2_id) REFERENCES genotype(genotype_id) ON DELETE CASCADE;


--
-- Name: phenotype_comparison_organism_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phenotype_comparison
    ADD CONSTRAINT phenotype_comparison_organism_id_fkey FOREIGN KEY (organism_id) REFERENCES organism(organism_id) ON DELETE CASCADE;


--
-- Name: phenotype_comparison_phenotype1_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phenotype_comparison
    ADD CONSTRAINT phenotype_comparison_phenotype1_id_fkey FOREIGN KEY (phenotype1_id) REFERENCES phenotype(phenotype_id) ON DELETE CASCADE;


--
-- Name: phenotype_comparison_phenotype2_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phenotype_comparison
    ADD CONSTRAINT phenotype_comparison_phenotype2_id_fkey FOREIGN KEY (phenotype2_id) REFERENCES phenotype(phenotype_id) ON DELETE CASCADE;


--
-- Name: phenotype_comparison_pub_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phenotype_comparison
    ADD CONSTRAINT phenotype_comparison_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES pub(pub_id) ON DELETE CASCADE;


--
-- Name: phenotype_cvalue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phenotype
    ADD CONSTRAINT phenotype_cvalue_id_fkey FOREIGN KEY (cvalue_id) REFERENCES cvterm(cvterm_id) ON DELETE SET NULL;


--
-- Name: phenotype_cvterm_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phenotype_cvterm
    ADD CONSTRAINT phenotype_cvterm_cvterm_id_fkey FOREIGN KEY (cvterm_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: phenotype_cvterm_phenotype_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phenotype_cvterm
    ADD CONSTRAINT phenotype_cvterm_phenotype_id_fkey FOREIGN KEY (phenotype_id) REFERENCES phenotype(phenotype_id) ON DELETE CASCADE;


--
-- Name: phenotype_observable_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phenotype
    ADD CONSTRAINT phenotype_observable_id_fkey FOREIGN KEY (observable_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: phenotypeprop_phenotype_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phenotypeprop
    ADD CONSTRAINT phenotypeprop_phenotype_id_fkey FOREIGN KEY (phenotype_id) REFERENCES phenotype(phenotype_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: phenotypeprop_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phenotypeprop
    ADD CONSTRAINT phenotypeprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: phenstatement_environment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phenstatement
    ADD CONSTRAINT phenstatement_environment_id_fkey FOREIGN KEY (environment_id) REFERENCES environment(environment_id) ON DELETE CASCADE;


--
-- Name: phenstatement_genotype_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phenstatement
    ADD CONSTRAINT phenstatement_genotype_id_fkey FOREIGN KEY (genotype_id) REFERENCES genotype(genotype_id) ON DELETE CASCADE;


--
-- Name: phenstatement_phenotype_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phenstatement
    ADD CONSTRAINT phenstatement_phenotype_id_fkey FOREIGN KEY (phenotype_id) REFERENCES phenotype(phenotype_id) ON DELETE CASCADE;


--
-- Name: phenstatement_pub_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phenstatement
    ADD CONSTRAINT phenstatement_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES pub(pub_id) ON DELETE CASCADE;


--
-- Name: phenstatement_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phenstatement
    ADD CONSTRAINT phenstatement_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: project_contact_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY project_contact
    ADD CONSTRAINT project_contact_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES contact(contact_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: project_contact_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY project_contact
    ADD CONSTRAINT project_contact_project_id_fkey FOREIGN KEY (project_id) REFERENCES project(project_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: project_pub_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY project_pub
    ADD CONSTRAINT project_pub_project_id_fkey FOREIGN KEY (project_id) REFERENCES project(project_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: project_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY project_pub
    ADD CONSTRAINT project_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: project_relationship_object_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY project_relationship
    ADD CONSTRAINT project_relationship_object_project_id_fkey FOREIGN KEY (object_project_id) REFERENCES project(project_id) ON DELETE CASCADE;


--
-- Name: project_relationship_subject_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY project_relationship
    ADD CONSTRAINT project_relationship_subject_project_id_fkey FOREIGN KEY (subject_project_id) REFERENCES project(project_id) ON DELETE CASCADE;


--
-- Name: project_relationship_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY project_relationship
    ADD CONSTRAINT project_relationship_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE RESTRICT;


--
-- Name: projectprop_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY projectprop
    ADD CONSTRAINT projectprop_project_id_fkey FOREIGN KEY (project_id) REFERENCES project(project_id) ON DELETE CASCADE;


--
-- Name: projectprop_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY projectprop
    ADD CONSTRAINT projectprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: pub_dbxref_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pub_dbxref
    ADD CONSTRAINT pub_dbxref_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: pub_dbxref_pub_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pub_dbxref
    ADD CONSTRAINT pub_dbxref_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: pub_relationship_object_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pub_relationship
    ADD CONSTRAINT pub_relationship_object_id_fkey FOREIGN KEY (object_id) REFERENCES pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: pub_relationship_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pub_relationship
    ADD CONSTRAINT pub_relationship_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: pub_relationship_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pub_relationship
    ADD CONSTRAINT pub_relationship_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: pub_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pub
    ADD CONSTRAINT pub_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: pubauthor_pub_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pubauthor
    ADD CONSTRAINT pubauthor_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: pubprop_pub_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pubprop
    ADD CONSTRAINT pubprop_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: pubprop_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pubprop
    ADD CONSTRAINT pubprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_cvterm_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stock_cvterm
    ADD CONSTRAINT stock_cvterm_cvterm_id_fkey FOREIGN KEY (cvterm_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_cvterm_pub_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stock_cvterm
    ADD CONSTRAINT stock_cvterm_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_cvterm_stock_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stock_cvterm
    ADD CONSTRAINT stock_cvterm_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES stock(stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_cvtermprop_stock_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stock_cvtermprop
    ADD CONSTRAINT stock_cvtermprop_stock_cvterm_id_fkey FOREIGN KEY (stock_cvterm_id) REFERENCES stock_cvterm(stock_cvterm_id) ON DELETE CASCADE;


--
-- Name: stock_cvtermprop_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stock_cvtermprop
    ADD CONSTRAINT stock_cvtermprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_dbxref_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stock_dbxref
    ADD CONSTRAINT stock_dbxref_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stock
    ADD CONSTRAINT stock_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_dbxref_stock_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stock_dbxref
    ADD CONSTRAINT stock_dbxref_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES stock(stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_dbxrefprop_stock_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stock_dbxrefprop
    ADD CONSTRAINT stock_dbxrefprop_stock_dbxref_id_fkey FOREIGN KEY (stock_dbxref_id) REFERENCES stock_dbxref(stock_dbxref_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_dbxrefprop_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stock_dbxrefprop
    ADD CONSTRAINT stock_dbxrefprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_genotype_genotype_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stock_genotype
    ADD CONSTRAINT stock_genotype_genotype_id_fkey FOREIGN KEY (genotype_id) REFERENCES genotype(genotype_id) ON DELETE CASCADE;


--
-- Name: stock_genotype_stock_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stock_genotype
    ADD CONSTRAINT stock_genotype_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES stock(stock_id) ON DELETE CASCADE;


--
-- Name: stock_organism_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stock
    ADD CONSTRAINT stock_organism_id_fkey FOREIGN KEY (organism_id) REFERENCES organism(organism_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stock_pub
    ADD CONSTRAINT stock_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_pub_stock_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stock_pub
    ADD CONSTRAINT stock_pub_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES stock(stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_relationship_cvterm_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stock_relationship_cvterm
    ADD CONSTRAINT stock_relationship_cvterm_cvterm_id_fkey FOREIGN KEY (cvterm_id) REFERENCES cvterm(cvterm_id) ON DELETE RESTRICT;


--
-- Name: stock_relationship_cvterm_pub_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stock_relationship_cvterm
    ADD CONSTRAINT stock_relationship_cvterm_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES pub(pub_id) ON DELETE RESTRICT;


--
-- Name: stock_relationship_cvterm_stock_relationship_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stock_relationship_cvterm
    ADD CONSTRAINT stock_relationship_cvterm_stock_relationship_id_fkey FOREIGN KEY (stock_relationship_id) REFERENCES stock_relationship(stock_relationship_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_relationship_object_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stock_relationship
    ADD CONSTRAINT stock_relationship_object_id_fkey FOREIGN KEY (object_id) REFERENCES stock(stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_relationship_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stock_relationship_pub
    ADD CONSTRAINT stock_relationship_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_relationship_pub_stock_relationship_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stock_relationship_pub
    ADD CONSTRAINT stock_relationship_pub_stock_relationship_id_fkey FOREIGN KEY (stock_relationship_id) REFERENCES stock_relationship(stock_relationship_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_relationship_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stock_relationship
    ADD CONSTRAINT stock_relationship_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES stock(stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_relationship_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stock_relationship
    ADD CONSTRAINT stock_relationship_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stock
    ADD CONSTRAINT stock_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stockcollection_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stockcollection
    ADD CONSTRAINT stockcollection_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES contact(contact_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stockcollection_stock_stock_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stockcollection_stock
    ADD CONSTRAINT stockcollection_stock_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES stock(stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stockcollection_stock_stockcollection_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stockcollection_stock
    ADD CONSTRAINT stockcollection_stock_stockcollection_id_fkey FOREIGN KEY (stockcollection_id) REFERENCES stockcollection(stockcollection_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stockcollection_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stockcollection
    ADD CONSTRAINT stockcollection_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: stockcollectionprop_stockcollection_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stockcollectionprop
    ADD CONSTRAINT stockcollectionprop_stockcollection_id_fkey FOREIGN KEY (stockcollection_id) REFERENCES stockcollection(stockcollection_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stockcollectionprop_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stockcollectionprop
    ADD CONSTRAINT stockcollectionprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id);


--
-- Name: stockprop_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stockprop_pub
    ADD CONSTRAINT stockprop_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stockprop_pub_stockprop_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stockprop_pub
    ADD CONSTRAINT stockprop_pub_stockprop_id_fkey FOREIGN KEY (stockprop_id) REFERENCES stockprop(stockprop_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stockprop_stock_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stockprop
    ADD CONSTRAINT stockprop_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES stock(stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stockprop_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stockprop
    ADD CONSTRAINT stockprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: synonym_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY synonym
    ADD CONSTRAINT synonym_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: public; Type: ACL; Schema: -; Owner: -
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

