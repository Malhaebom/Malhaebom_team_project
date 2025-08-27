import { useState } from 'react'
import { useNavigate, useLocation } from 'react-router-dom'


const Background = () => {
    return (
        <div>
            <div className="logo_bg">
                <img src="/img/logo-bg.png" alt="로고" />
                <p>말로 피어나는 추억의 꽃,<br />
                    <strong>말해봄과 함께하세요.</strong></p>
            </div>
            <div className="character">
                <img src="/img/Character-bg.png" alt="캐릭터" />
            </div>
        </div>
    )
}

export default Background