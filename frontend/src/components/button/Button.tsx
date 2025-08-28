import { useState } from 'react';
import './button.css';

export interface ButtonProps {
  variant?: 'primary' | 'secondary' | 'danger';
  children: React.ReactNode;
  onClick?: () => void;
  disabled?: boolean;
}

export const Button = ({ 
  variant = 'primary', 
  children, 
  onClick, 
  disabled = false 
}: ButtonProps) => {
  const [isPressed, setIsPressed] = useState(false);

  const handleClick = () => {
    if (!disabled && onClick) {
      onClick();
    }
  };

  const handleMouseDown = () => setIsPressed(true);
  const handleMouseUp = () => setIsPressed(false);
  const handleMouseLeave = () => setIsPressed(false);

  const baseClass = 'btn';
  const variantClass = `btn--${variant}`;
  const disabledClass = disabled ? 'btn--disabled' : '';
  const pressedClass = isPressed && !disabled ? 'btn--pressed' : '';

  const className = [baseClass, variantClass, disabledClass, pressedClass]
    .filter(Boolean)
    .join(' ');

  return (
    <button
      className={className}
      onClick={handleClick}
      onMouseDown={handleMouseDown}
      onMouseUp={handleMouseUp}
      onMouseLeave={handleMouseLeave}
      disabled={disabled}
      type="button"
    >
      {children}
    </button>
  );
};

export default Button;