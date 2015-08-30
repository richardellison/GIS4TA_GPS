<?php

### Run the following two commands from the command line to import the data
### First command creates a 'gisruk' database with a 'gpsdata' table and necessary columns
### Second command runs this script
# cat creategpsdb.sql | sudo su -c psql postgres
# cat insertGPS.php | sudo su -c php postgres

$con = pg_connect("dbname=gisruk");

$count = 101;
$firstid = 1;
$lastid = -1;
while ($count <= 177) {
	$query = "COPY gpsdata(obstimei,lat,lng,spd) FROM '" . realpath(dirname(__FILE__)) . "/data/veh" . $count . ".csv' DELIMITER ',' CSV HEADER;";
	$queryResp = pg_query($con, $query);
	$numInserted = pg_affected_rows($queryResp);
	$lastid = $firstid + $numInserted;
	$query = "UPDATE gpsdata SET vehid = $count, latlng = ST_SetSRID(ST_MakePoint(lng, lat), 4326), obstime = to_timestamp(obstimei) WHERE obsid >= $firstid AND obsid < $lastid;";
	$queryResp = pg_query($con, $query);
	$firstid = $lastid;
	$count = $count + 1;
}

pg_close($con);

?>
