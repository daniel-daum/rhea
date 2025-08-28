import './sidebar.css';

export interface SidebarProps {
  // Props
  enabled: boolean;
}

export function Sidebar({enabled}:SidebarProps) {
  // Logic
  
  
  // 
  const baseClass = 'sidebar';
  const className = [baseClass]
    .filter(Boolean)
    .join(' ');
  
  // JSX
  return (
    <>
      <div className={className}>
        i am a sidebar i am: {enabled}
      </div>
    </>
  )}

export default Sidebar;
