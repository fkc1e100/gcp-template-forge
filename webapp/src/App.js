import React, { useState, useEffect } from 'react';
import './App.css';

function App() {
  const [progress, setProgress] = useState({});

  useEffect(() => {
    const eventSource = new EventSource('/api/progress');

    eventSource.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        setProgress(data);
      } catch (error) {
        console.error("Error parsing JSON:", error);
      }
    };

    eventSource.onerror = (error) => {
      console.error("EventSource failed:", error);
      eventSource.close();
    };

    return () => {
      eventSource.close();
    };
  }, []);

  return (
    <div className="App">
      <header className="App-header">
        <h1>GCP Template Forge Dashboard</h1>
        <div>
          <h2>Progress:</h2>
          <pre>{JSON.stringify(progress, null, 2)}</pre>
        </div>
      </header>
    </div>
  );
}

export default App;
