import React, { useEffect, useRef } from "react";
import mapboxgl from "mapbox-gl";

export default function SocMap({ alerts = [] }) {
  const mapContainer = useRef(null);
  const mapRef = useRef(null);

  useEffect(() => {
    if (!mapRef.current) {
      mapboxgl.accessToken = process.env.NEXT_PUBLIC_MAPBOX_TOKEN;
      mapRef.current = new mapboxgl.Map({
        container: mapContainer.current,
        style: "mapbox://styles/mapbox/light-v11",
        center: [46.6753, 24.7136],
        zoom: 3
      });
    }
    return () => {};
  }, []);

  useEffect(() => {
    if (!mapRef.current) return;
    // remove existing markers
    if (mapRef.current.__markers) {
      mapRef.current.__markers.forEach(m => m.remove());
    }
    mapRef.current.__markers = [];

    alerts.forEach(a => {
      if (!a.lat || !a.lon) return;
      const el = document.createElement("div");
      el.style.width = "14px";
      el.style.height = "14px";
      el.style.borderRadius = "50%";
      const color = a.risk === "Critical" ? "#9b2c2c" : a.risk === "High" ? "#ef4444" : a.risk === "Medium" ? "#f59e0b" : a.risk === "Low" ? "#60a5fa" : "#16a34a";
      el.style.background = color;
      const marker = new mapboxgl.Marker(el).setLngLat([a.lon, a.lat]).setPopup(new mapboxgl.Popup().setHTML(`<b>${a.user}</b><br>${a.app}<br>${a.ip}<br><small>${a.location}</small>`)).addTo(mapRef.current);
      mapRef.current.__markers.push(marker);
    });
  }, [alerts]);

  return <div className="card right-panel" style={{padding:0}}>
    <div id="map" ref={mapContainer} style={{height:360}} />
  </div>;
}
