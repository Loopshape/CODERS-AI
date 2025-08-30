import React from 'react';

const CodeIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" className="h-8 w-8 text-cyan-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
    <path strokeLinecap="round" strokeLinejoin="round" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4" />
  </svg>
);

const Header: React.FC = () => {
  return (
    <header className="bg-gray-900/70 backdrop-blur-lg p-4 border-b border-gray-700 fixed top-0 left-0 right-0 z-10">
      <div className="container mx-auto flex items-center gap-4 px-4">
        <CodeIcon />
        <h1 className="text-2xl font-bold text-white tracking-wider">
          Gemini Code Reviewer
        </h1>
      </div>
    </header>
  );
};

export default Header;
