import "./sidebarButton.css";

export interface SidebarButtonProps {
    text:string;

}


function SidebarButton(props:SidebarButtonProps) {
    return (
        <div className="sidebarButton">
            <p className="sidebarButton-text">{props.text}</p>
        </div>
    );
}

export default SidebarButton;
