import React from 'react';
import './Pagination.css';

const Pagination = ({ 
  currentPage, 
  totalPages, 
  onPageChange,
  itemsPerPage = 5 
}) => {
  // 페이지가 1개 이하면 페이징을 표시하지 않음
  if (totalPages <= 1) return null;

  return (
    <div className="pagination-container">
      {/* 이전 페이지 버튼 */}
      <button
        className="pagination-button"
        onClick={() => currentPage > 1 && onPageChange(currentPage - 1)}
        disabled={currentPage === 1}
        aria-label="이전 페이지"
      >
        ‹
      </button>

      {/* 현재 페이지 번호 */}
      <div className="pagination-current-page">
        {currentPage}
      </div>

      {/* 다음 페이지 버튼 */}
      <button
        className="pagination-button"
        onClick={() => currentPage < totalPages && onPageChange(currentPage + 1)}
        disabled={currentPage === totalPages}
        aria-label="다음 페이지"
      >
        ›
      </button>
    </div>
  );
};

export default Pagination;
