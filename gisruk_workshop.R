# Load RPostgreSQL library so that we can connect to the database
library("RPostgreSQL")

# Specify the database type
drv <- dbDriver("PostgreSQL")
# Connect to the database.  Since we're connecting to a server on another
# computer with a different username and password, we need to specify these.
# Otherwise we would only need to specify the database name (dbname)
con <- dbConnect(drv, dbname="gisruk", host="10.3.3.102", user="gisruk", password="kursig")

# We run a small query to make sure it works
# and output the result to the rs (resultset) data frame
rs <- dbGetQuery(con,"SELECT * FROM gpsdata LIMIT 10")

# You will notice a warning message about the field type geometry being unrecognised
# This is because the postgis field types are not recognised by the DBI driver we are
# using.  This can be ignored because the field it is referring to is only used within
# the query and this is processed by PostgreSQL/PostGIS itself.

# To get a feel for the data, lets just see how many observations there are per vehicle
# and the average speed.
# In PostgreSQL count(*) can be quite slow unless it is run on a field with an index
rs <- dbGetQuery(con,"SELECT vehid, count(*) as numobs, avg(spd) as avgspd, stddev_pop(spd) as sdspd FROM gpsdata GROUP BY vehid")

# The average speed that is calculated here is not actually the average speed.  It is the average
# of the speed recorded at the time of each observation.  If the interval between observations varies
# or is too far apart (>1 second), you would need to determine the elapsed time between
# consecutive points, calculate the distance and use those values to determine a speed between
# observations.  Only then could you calculate an average speed. However, for our purposes in this
# workshop we'll assume that this is the 'true' average speed.

# Load the ggplot2 library so we can plot this
library("ggplot2")

# Plot the average speed and the standard deviation of the speeds for each vehicle
ggplot(rs, aes(x=factor(vehid),y=avgspd,fill=sdspd)) + geom_bar(stat="identity")

# Most vehicles seem to have an average speed of between 25 and 35 miles/hour but 
# some are below that with quite a small standard deviation which is unusual in a
# driving situation which (usually) requires some acceleration and braking behviour.
# We can run a query that pulls the individual observations for these vehicles

# Find the vehicles that were travelling above 75 miles per hour on a specific road.

fastloc <- dbGetQuery(con,"SELECT DISTINCT vehid FROM gpsdata, planet_osm_roads WHERE ST_DWithin(ST_Transform(way, 4326), latlng, 0.00001) AND highway='motorway' AND spd > 75 AND osm_id = 98969782 ORDER BY vehid LIMIT 10000;")

View(fastloc)

# We could do this within the SQL query but we're going to do it in R manually
# for demonstration purposes

svid <- rs[which(rs$avgspd < 25),]

View(svid)

# svid has five observations: 171,156,110,123,165
# Usually we wouldn't do it this way because there could be hundreds of vehicles
# that would be included.

slowvehs <- dbGetQuery(con,"SELECT obsid,lat,lng,spd,heading,vehid FROM gpsdata WHERE vehid IN (171,156,110,123,165)")

# Now we have the observations we can look at more detail at these observations
ggplot(slowvehs, aes(x=spd,colour=factor(vehid),group=factor(vehid))) + geom_density()

# Seems quite similar to each other (although there are differences)

# How does this compare with the faster vehicles?
# Get the raw data (this may take a while)
fastvehs <- dbGetQuery(con,"SELECT obsid,lat,lng,spd,heading,vehid FROM gpsdata WHERE vehid NOT IN (171,156,110,123,165)")
ggplot(fastvehs, aes(x=spd,colour=factor(vehid),group=factor(vehid))) + geom_density()

# Quite a different pattern - question is why?
# Lets do a spatial density plot by speed and slow/fast vehicles

# Bin speeds first
slowvehs$spdbins <- .bincode(slowvehs$spd, c(0,20,40,60,80,100), right = TRUE, include.lowest = FALSE)
fastvehs$spdbins <- .bincode(fastvehs$spd, c(0,20,40,60,80,100), right = TRUE, include.lowest = FALSE)

# Then plot based on lat/long and speed bin
ggplot() + stat_density2d(
  data=slowvehs,
  aes(x=lng,y=lat, colour=factor(spdbins),fill=factor(spdbins),alpha = ..level.. ),
  size = 1,
  bins = 5,
  geom = "polygon")

# Strange shapes, specify limits of plot
ggplot() + stat_density2d(
  data=slowvehs,
  aes(x=lng,y=lat, colour=factor(spdbins),fill=factor(spdbins),alpha = ..level.. ),
  size = 1,
  bins = 5,
  geom = "polygon") + scale_x_continuous(limits=c(-122.11,-122.04)) + scale_y_continuous(limits=c(37.56,37.67))

# Do the same with fast vehicles
ggplot() + stat_density2d(
  data=fastvehs,
  aes(x=lng,y=lat, colour=factor(spdbins),fill=factor(spdbins),alpha = ..level.. ),
  size = 1,
  bins = 5,
  geom = "polygon") + scale_x_continuous(limits=c(-122.15,-122.0)) + scale_y_continuous(limits=c(37.50,37.70))

# You will probably see a few warnings about rows needing to be dropped due to non-finite errors.
# This is due to the number of observations being included (513,880) which is likely too large
# for this particular function.



# Retrieve motorway and subset of observations.
# Code below has been adapted from: https://geospatial.commons.gc.cuny.edu/2014/01/14/load-postgis-geometries-in-r-without-rgdal/

strSQL = "
SELECT osm_id, ST_AsText(ST_Transform(way,4326)) AS wkt_geometry, highway, name FROM planet_osm_roads WHERE highway='motorway'"
motorwayTemp = dbGetQuery(conn, strSQL)
row.names(motorwayTemp) = motorwayTemp$osm_id

# Create spatial polygons
# To set the PROJ4 string, enter the EPSG SRID and uncomment the 
# following two lines:
# EPSG = make_EPSG()
# p4s = EPSG[which(EPSG$code == SRID), "prj4"]
for (i in seq(nrow(motorwayTemp))) {
  if (i == 1) {
    spTemp = readWKT(motorwayTemp$wkt_geometry[i], motorwayTemp$osm_id[i])
    # If the PROJ4 string has been set, use the following instead
    # spTemp = readWKT(dfTemp$wkt_geometry[i], dfTemp$gid[i], p4s)
  }
  else {
    spTemp = rbind(
      spTemp, readWKT(motorwayTemp$wkt_geometry[i], motorwayTemp$osm_id[i])
      # If the PROJ4 string has been set, use the following instead
      # spTemp, readWKT(dfTemp$wkt_geometry[i], dfTemp$gid[i], p4s)
    )
  }
}

motorway <- spTemp

# Create SpatialPolygonsDataFrame, drop WKT field from attributes
motorwayFinal = SpatialLinesDataFrame(motorway, motorwayTemp[-2])


rm(spTemp)

strSQL = "
SELECT obsid, ST_AsText(latlng) AS wkt_geometry, obstime, lat, lng, spd, heading, vehid FROM gpsdata"
dfTemp = dbGetQuery(conn, strSQL)
row.names(dfTemp) = dfTemp$osm_id
dfGPS <- dfTemp;

# Create spatial polygons
# To set the PROJ4 string, enter the EPSG SRID and uncomment the 
# following two lines:
# EPSG = make_EPSG()
# p4s = EPSG[which(EPSG$code == SRID), "prj4"]
for (i in seq(nrow(dfTemp))) {
  if (i == 1) {
    spTemp = readWKT(dfTemp$wkt_geometry[i], dfTemp$osm_id[i])
    # If the PROJ4 string has been set, use the following instead
    # spTemp = readWKT(dfTemp$wkt_geometry[i], dfTemp$gid[i], p4s)
  }
  else {
    spTemp = rbind(
      spTemp, readWKT(dfTemp$wkt_geometry[i], dfTemp$osm_id[i])
      # If the PROJ4 string has been set, use the following instead
      # spTemp, readWKT(dfTemp$wkt_geometry[i], dfTemp$gid[i], p4s)
    )
  }
}



motorway.f <- fortify(motorwayFinal,region='osm_id')

save(motorway.f, file="motorwayFinal.RData")


ggplot() + geom_path(data=motorway.f,aes(x=long,y=lat,group=group),size=3,colour='grey') + geom_point(data=dfGPS[which(dfGPS$vehid <= 110 & (dfGPS$heading > 270 | dfGPS$heading < 90)),],aes(x=lng,y=lat,colour=spd),alpha=0.1) + 
  facet_wrap( ~ vehid, nrow = 2)

dfGPS <- dfGPS[order(dfGPS$vehid,dfGPS$obstime),]

save(dfGPS, file="dfGPS.RData")

ggplot() + geom_point(data=dfGPS[which(dfGPS$vehid <= 110 & (dfGPS$heading > 270 | dfGPS$heading < 90)),],aes(x=lng,y=lat,colour=spd,group=vehid),alpha=0.1) + 
  facet_wrap( ~ vehid, nrow = 2)


