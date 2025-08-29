// src/ScoreContext.jsx
import React, { createContext, useContext, useMemo, useState } from "react";

const ScoreContext = createContext(null);

export function ScoreProvider({ children }) {
  const [scoreAD, setScoreAD] = useState(0);
  const [scoreAI, setScoreAI] = useState(0);
  const [scoreB, setScoreB] = useState(0);
  const [scoreC, setScoreC] = useState(0);
  const [scoreD, setScoreD] = useState(0);

  const resetScores = () => {
    setScoreAD(0);
    setScoreAI(0);
    setScoreB(0);
    setScoreC(0);
    setScoreD(0);
  };

  const value = useMemo(
    () => ({
      scoreAD,
      scoreAI,
      scoreB,
      scoreC,
      scoreD,
      setScoreAD,
      setScoreAI,
      setScoreB,
      setScoreC,
      setScoreD,
      resetScores,
    }),
    [scoreAD, scoreAI, scoreB, scoreC, scoreD]
  );

  return <ScoreContext.Provider value={value}>{children}</ScoreContext.Provider>;
}

export function useScores() {
  const ctx = useContext(ScoreContext);
  if (!ctx) throw new Error("useScores must be used within ScoreProvider");
  return ctx;
}

// ✅ default export 추가: App.jsx에서 `import ScoreProvider from "./ScoreContext.jsx";`로도 사용 가능
export default ScoreProvider;
