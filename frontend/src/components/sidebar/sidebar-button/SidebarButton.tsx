import "./sidebarButton.css";

export interface SidebarButtonProps {
    text:string;
    onClick: () => void;
}


function SidebarButton(props:SidebarButtonProps) {
    return (
        <div className="sidebarButton" onClick={props.onClick}>
            <p className="sidebarButton-text">{props.text}</p>
        </div>
    );
}

export default SidebarButton;
