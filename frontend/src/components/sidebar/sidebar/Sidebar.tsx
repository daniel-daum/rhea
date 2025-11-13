import "./sidebar.css";
import SidebarButton from "../sidebar-button/SidebarButton";


export interface SidebarProps {
  onViewChange: (view: string) => void;
}

function Sidebar({ onViewChange }: SidebarProps){
  return (
      <div className="sidebar">
        <div className="sidebar-title"><h1>RHEA</h1></div>
        
      <SidebarButton text="Store" onClick={() => onViewChange("Store")}></SidebarButton>
      
      <SidebarButton text="Reciept" onClick={() => onViewChange("Reciept")}></SidebarButton>
      
      <SidebarButton text="Groceries" onClick={() => onViewChange("Groceries")}></SidebarButton>
      </div>
  );
}

export default Sidebar;
