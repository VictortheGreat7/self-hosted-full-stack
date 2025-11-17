import { useEffect, useState } from 'react';
import ClockOrbit from './ClockOrbit';
import './CityCard.css';

function CityCard({ city, is24Hour, animationDelay }) {
  const [currentTime, setCurrentTime] = useState(new Date());

  useEffect(() => {
    // Parse the datetime from the city data
    const cityDate = new Date(city.datetime);
    setCurrentTime(cityDate);

    // Update every second
    const interval = setInterval(() => {
      setCurrentTime(prevTime => new Date(prevTime.getTime() + 1000));
    }, 1000);

    return () => clearInterval(interval);
  }, [city.datetime]);

  const formatTime = (date) => {
    if (is24Hour) {
      return date.toLocaleTimeString('en-US', { 
        hour: '2-digit', 
        minute: '2-digit', 
        second: '2-digit',
        hour12: false 
      });
    } else {
      return date.toLocaleTimeString('en-US', { 
        hour: '2-digit', 
        minute: '2-digit', 
        second: '2-digit',
        hour12: true 
      });
    }
  };

  const formatDate = (date) => {
    return date.toLocaleDateString('en-US', {
      weekday: 'short',
      month: 'short',
      day: 'numeric'
    });
  };

  // Color schemes for different regions
  const getColorScheme = () => {
    const schemes = [
      { primary: '#6366f1', secondary: '#818cf8' }, // Indigo
      { primary: '#8b5cf6', secondary: '#a78bfa' }, // Purple
      { primary: '#ec4899', secondary: '#f472b6' }, // Pink
      { primary: '#f59e0b', secondary: '#fbbf24' }, // Amber
      { primary: '#10b981', secondary: '#34d399' }, // Emerald
      { primary: '#06b6d4', secondary: '#22d3ee' }, // Cyan
      { primary: '#ef4444', secondary: '#f87171' }, // Red
      { primary: '#3b82f6', secondary: '#60a5fa' }, // Blue
    ];
    
    const hash = city.city.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0);
    return schemes[hash % schemes.length];
  };

  const colorScheme = getColorScheme();

  return (
    <div 
      className={`city-card ${city.is_day ? 'day' : 'night'}`}
      style={{
        '--primary-color': colorScheme.primary,
        '--secondary-color': colorScheme.secondary,
        animationDelay: `${animationDelay}s`
      }}
    >
      <div className="city-card-header">
        <h3 className="city-name">{city.city}</h3>
        <span className={`day-night-indicator ${city.is_day ? 'day' : 'night'}`}>
          {city.is_day ? '☀️' : '🌙'}
        </span>
      </div>

      <ClockOrbit time={currentTime} colorScheme={colorScheme} />

      <div className="city-info">
        <div className="time-display">
          {formatTime(currentTime)}
        </div>
        <div className="date-display">
          {formatDate(currentTime)}
        </div>
        <div className="timezone-info">
          <span className="timezone-offset">UTC {city.offset_hours >= 0 ? '+' : ''}{city.offset_hours}</span>
          {city.is_dst && <span className="dst-indicator">DST</span>}
        </div>
      </div>
    </div>
  );
}

export default CityCard;
