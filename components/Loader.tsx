import React from 'react';

const Loader: React.FC = () => (
  <div className="absolute inset-0 bg-gray-800/50 backdrop-blur-sm flex flex-col items-center justify-center gap-4 rounded-lg">
    <div className="w-16 h-16 border-4 border-dashed rounded-full animate-spin border-cyan-400"></div>
    <p className="text-cyan-200 text-lg tracking-wider">Gemini is thinking...</p>
  </div>
);

export default Loader;
