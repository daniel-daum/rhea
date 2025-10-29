import "./sidebar.css";
import SidebarButton from "../sidebar-button/SidebarButton";

export interface SidebarProps {
  primary?: boolean;
  expanded:boolean;
  color_mode?: string;
}


function Sidebar(){
  return (
      <div className="sidebar">
        <div className="sidebar-title"><h1>RHEA</h1></div>
      <SidebarButton text="Store"></SidebarButton>
      <SidebarButton text="Reciept"></SidebarButton>
      <SidebarButton text="Groceries"></SidebarButton>
      </div>
  );
}

export default Sidebar;
