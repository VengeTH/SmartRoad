FROM ghcr.io/graphhopper/graphhopper:latest

# * Copy custom configuration
COPY config.yml /graphhopper/config-example.yml

# * Set working directory
WORKDIR /graphhopper

# * Expose GraphHopper port
EXPOSE 8989

# * Default command - will download and import Philippines OSM data on first run
CMD ["java", "-Xmx2g", "-Xms2g", "-Ddw.graphhopper.datareader.file=philippines-latest.osm.pbf", "-Ddw.graphhopper.graph.location=graph-cache", "-jar", "graphhopper-web.jar", "server", "config-example.yml"]





