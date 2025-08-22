// src/App.jsx
import React from "react";
import { Routes, Route, Navigate } from "react-router-dom";

// Pages
import Home from "./pages/Home.jsx";

// 로그인 추가
// Login
import Login from "./pages/Login/Login.jsx"

// Interview 추가
import Interview from "./pages/Interview/InterviewStart.jsx";

// Book > Training
import Course from "./pages/Book/Training/Course.jsx";

// Book > Training > course
import ExamTut from "./pages/Book/Training/course/ExamTut.jsx";
import StartExam from "./pages/Book/Training/course/StartExam.jsx";
import ResultExam from "./pages/Book/Training/course/ResultExam.jsx";
import PlayList from "./pages/Book/Training/course/PlayList.jsx";
import PlayStart from "./pages/Book/Training/course/PlayStart.jsx";
import Read from "./pages/Book/Training/course/Read.jsx";
import Workbook from "./pages/Book/Training/course/Workbook.jsx";
import WorkbookStart from "./pages/Book/Training/course/WorkbookStart.jsx";

// Book > Library
import BookLibrary from "./pages/Book/Library.jsx";

// Exercise
import ExerciseList from "./pages/Exercise/ExerciseList.jsx";
import ExerciseDo from "./pages/Exercise/ExerciseDo.jsx";

// Quiz
import QuizLibrary from "./pages/Quiz/QuizLibrary.jsx";
import QuizList from "./pages/Quiz/QuizList.jsx";
import QuizPlay from "./pages/Quiz/QuizPlay.jsx";

// Context (default export 사용)
import ScoreProvider from "./ScoreContext.jsx";

/** ─────────────────────────────────────────────────────────────
 * 간단한 에러 바운더리: 어느 라우트에서 깨지는지 바로 표시
 * (문제 해결 후 삭제해도 됩니다)
 * ──────────────────────────────────────────────────────────── */
class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { err: null };
  }
  static getDerivedStateFromError(error) {
    return { err: error };
  }
  componentDidCatch(error, info) {
    console.error(`[ErrorBoundary:${this.props.name}]`, error, info);
  }
  render() {
    if (this.state.err) {
      return (
        <div style={{ padding: 16, background: "#ffecec", border: "1px solid #f00" }}>
          <strong>컴포넌트 오류</strong> — {this.props.name}
          <pre style={{ whiteSpace: "pre-wrap", marginTop: 8 }}>
            {String(this.state.err)}
          </pre>
        </div>
      );
    }
    return this.props.children;
  }
}

// (임시) import 확인용 — 필요없으면 제거하세요.
console.table({
  Home: !!Home,
  Course: !!Course,
  ExamTut: !!ExamTut,
  StartExam: !!StartExam,
  ResultExam: !!ResultExam,
  PlayList: !!PlayList,
  PlayStart: !!PlayStart,
  Read: !!Read,
  Workbook: !!Workbook,
  WorkbookStart: !!WorkbookStart,
  BookLibrary: !!BookLibrary,
  ExerciseList: !!ExerciseList,
  ExerciseDo: !!ExerciseDo,
  QuizLibrary: !!QuizLibrary,
  QuizList: !!QuizList,
  QuizPlay: !!QuizPlay,
  ScoreProvider: !!ScoreProvider,
});

export default function App() {
  return (
    <ScoreProvider>
      <Routes>
        {/* 홈 */}
        <Route
          path="/"
          element={
            <ErrorBoundary name="Home">
              <Home />
            </ErrorBoundary>
          }
        />

        {/* 로그인 */}
        <Route
          path="/login"
          element={
            <ErrorBoundary name="login">
              <Login />
            </ErrorBoundary>
          }
        />

        {/* 인터뷰 */}
        <Route
          path="/interview/interviewstart"
          element={
            <ErrorBoundary name="interview">
              <Interview />
            </ErrorBoundary>
          }
        />

        {/* 회상동화 진입 */}
        <Route
          path="/book/library"
          element={
            <ErrorBoundary name="BookLibrary">
              <BookLibrary />
            </ErrorBoundary>
          }
        />
        <Route
          path="/book/training"
          element={
            <ErrorBoundary name="Course">
              <Course />
            </ErrorBoundary>
          }
        />

        {/* 화행검사 */}
        <Route
          path="/book/training/course/exam"
          element={
            <ErrorBoundary name="ExamTut">
              <ExamTut />
            </ErrorBoundary>
          }
        />
        <Route
          path="/book/training/course/exam/start"
          element={
            <ErrorBoundary name="StartExam">
              <StartExam />
            </ErrorBoundary>
          }
        />
        <Route
          path="/book/training/course/exam/result"
          element={
            <ErrorBoundary name="ResultExam">
              <ResultExam />
            </ErrorBoundary>
          }
        />

        {/* 동화 연극/시청 */}
        <Route
          path="/book/training/course/read"
          element={
            <ErrorBoundary name="Read">
              <Read />
            </ErrorBoundary>
          }
        />
        <Route
          path="/book/training/course/play"
          element={
            <ErrorBoundary name="PlayList">
              <PlayList />
            </ErrorBoundary>
          }
        />
        <Route
          path="/book/training/course/play/start"
          element={
            <ErrorBoundary name="PlayStart">
              <PlayStart />
            </ErrorBoundary>
          }
        />

        {/* 워크북 */}
        <Route
          path="/book/training/course/workbook"
          element={
            <ErrorBoundary name="Workbook">
              <Workbook />
            </ErrorBoundary>
          }
        />
        <Route
          path="/book/training/course/workbook/start"
          element={
            <ErrorBoundary name="WorkbookStart">
              <WorkbookStart />
            </ErrorBoundary>
          }
        />

        {/* 신체 단련 */}
        <Route
          path="/exercise"
          element={
            <ErrorBoundary name="ExerciseList">
              <ExerciseList />
            </ErrorBoundary>
          }
        />
        <Route
          path="/exercise/do"
          element={
            <ErrorBoundary name="ExerciseDo">
              <ExerciseDo />
            </ErrorBoundary>
          }
        />

        {/* 두뇌 단련 */}
        <Route
          path="/quiz/library"
          element={
            <ErrorBoundary name="QuizLibrary">
              <QuizLibrary />
            </ErrorBoundary>
          }
        />
        <Route
          path="/quiz/library/list"
          element={
            <ErrorBoundary name="QuizList">
              <QuizList />
            </ErrorBoundary>
          }
        />
        <Route
          path="/quiz/play"
          element={
            <ErrorBoundary name="QuizPlay">
              <QuizPlay />
            </ErrorBoundary>
          }
        />

        {/* fallback */}
        <Route path="*" element={<Navigate to="/book/library" replace />} />
      </Routes>
    </ScoreProvider>
  );
}
