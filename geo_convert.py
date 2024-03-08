import geopandas as gpd
from fiona.drvsupport import supported_drivers

supported_drivers['KML'] = 'rw'

# Read the KML file into a GeoDataFrame
kml_file = "RoadNetwork.kml"
gdf = gpd.read_file(kml_file, driver='KML')

# Write the GeoDataFrame to a shapefile
shp_file = "RoadNetwork.shp"
gdf.to_file(shp_file, driver='ESRI Shapefile')