CREATE DATABASE gisruk;
\connect gisruk;
CREATE EXTENSION postgis;
CREATE TABLE public.gpsdata
(
   obsid bigserial, 
   obstimei bigint,
   obstime timestamp, 
   lat numeric(20,10), 
   lng numeric(20,10), 
   spd numeric, 
   vehid bigint, 
   CONSTRAINT pkgpsdata PRIMARY KEY (obsid)
) WITH (
  OIDS = FALSE
);
SELECT AddGeometryColumn('gpsdata','latlng',4326,'POINT',2);
ALTER DATABASE gisruk SET timezone TO 'America/Los_Angeles';
