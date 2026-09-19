import { useState, useEffect } from 'react'
import './App.css'
import { lessons } from './data/lessons'

interface Message {
  type: 'bot' | 'user' | 'question' | 'quiz';
  content: string;
  options?: any[];
  feedback?: string;
  explanation?: string;
}

function App() {
  const [selectedLessonIndex, setSelectedLessonIndex] = useState<number | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [currentSectionIndex, setCurrentSectionIndex] = useState(0);
  const [currentMessageIndex, setCurrentMessageIndex] = useState(0);
  const [showOptions, setShowOptions] = useState(false);

  const lesson = selectedLessonIndex !== null ? lessons[selectedLessonIndex] : null;
  const currentSection = lesson?.sections[currentSectionIndex];

  useEffect(() => {
    if (!lesson || !currentSection) return;

    if (currentMessageIndex < currentSection.messages.length) {
      const timer = setTimeout(() => {
        const nextMsg = currentSection.messages[currentMessageIndex] as Message;
        setMessages(prev => [...prev, nextMsg]);

        if (nextMsg.type === 'bot') {
          setCurrentMessageIndex(prev => prev + 1);
        } else {
          setShowOptions(true);
        }
      }, 1000);
      return () => clearTimeout(timer);
    } else if (currentSectionIndex < lesson.sections.length - 1) {
      const timer = setTimeout(() => {
        setCurrentSectionIndex(prev => prev + 1);
        setCurrentMessageIndex(0);
      }, 2000);
      return () => clearTimeout(timer);
    }
  }, [currentMessageIndex, currentSectionIndex, lesson, currentSection]);

  const handleOptionClick = (option: any) => {
    setShowOptions(false);
    setMessages(prev => [...prev, { type: 'user', content: option.label }]);

    if (option.feedback || option.explanation) {
      setTimeout(() => {
        setMessages(prev => [...prev, {
          type: 'bot',
          content: option.feedback || option.explanation
        }]);
        setCurrentMessageIndex(prev => prev + 1);
      }, 800);
    } else {
      setCurrentMessageIndex(prev => prev + 1);
    }
  };

  if (selectedLessonIndex === null) {
    return (
      <div className="App">
        <header style={{ padding: '24px', textAlign: 'center', backgroundColor: 'white', borderBottom: '1px solid #DADCE0' }}>
          <h1 style={{ color: '#4285F4', marginBottom: '8px' }}>Aprendizado Digital TDS</h1>
          <p style={{ color: '#5F6368' }}>Escolha uma trilha para começar</p>
        </header>
        <div style={{ padding: '20px', display: 'flex', flexDirection: 'column', gap: '12px' }}>
          {lessons.map((l, idx) => (
            <button
              key={l.id}
              className="option-button"
              style={{ padding: '20px', fontSize: '18px', textAlign: 'left', border: '1px solid #DADCE0' }}
              onClick={() => setSelectedLessonIndex(idx)}
            >
              <strong>{l.title}</strong>
              <div style={{ fontSize: '14px', marginTop: '4px', opacity: 0.8 }}>{l.author}</div>
            </button>
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="App">
      <div className="progress-bar">
        <div
          className="progress-fill"
          style={{ width: `${((currentSectionIndex) / lesson!.sections.length) * 100}%` }}
        ></div>
      </div>

      <header style={{ padding: '16px', borderBottom: '1px solid #DADCE0', backgroundColor: 'white', display: 'flex', alignItems: 'center', gap: '12px' }}>
        <button onClick={() => setSelectedLessonIndex(null)} style={{ background: 'none', border: 'none', fontSize: '20px', cursor: 'pointer' }}>←</button>
        <h1 style={{ fontSize: '18px', margin: 0 }}>{lesson!.title}</h1>
      </header>

      <div className="chat-container">
        {messages.map((msg, idx) => (
          <div key={idx} className={`message ${msg.type === 'user' ? 'user' : 'bot'}`}>
            {msg.content}
          </div>
        ))}

        {showOptions && currentSection?.messages[currentMessageIndex]?.type === 'question' && (
          <div className="options-container">
            {(currentSection.messages[currentMessageIndex] as any).options.map((opt: any, i: number) => (
              <button key={i} className="option-button" onClick={() => handleOptionClick(opt)}>
                {opt.label}
              </button>
            ))}
          </div>
        )}

        {showOptions && currentSection?.messages[currentMessageIndex]?.type === 'quiz' && (
          <div className="options-container">
            {(currentSection.messages[currentMessageIndex] as any).options.map((opt: any, i: number) => (
              <button key={i} className="option-button" onClick={() => handleOptionClick(opt)}>
                {opt.label}
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

export default App
