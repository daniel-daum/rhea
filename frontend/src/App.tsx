import { useState } from "react";
import "./App.css";

import Sidebar from "./components/sidebar/sidebar/Sidebar";
import GroceryView from "./components/views/GroceryView";
import ReceiptView from "./components/views/RecieptView";
import StoreView from "./components/views/StoreView";
import ChainView from "./components/views/ChainView";

function App() {
  const [activeView, setActiveView] = useState("Store");

  const renderView = () => {
    switch (activeView) {
      case "Chain":
        return <ChainView />;
      case "Store":
        return <StoreView />;
      case "Reciept":
        return <ReceiptView />;
      case "Groceries":
        return <GroceryView />;
      default:
        return <ChainView />;
    }
  };

  return (
    <div className="app-sidebar">
      <Sidebar onViewChange={setActiveView}></Sidebar>
      <div className="app-main">{renderView()}</div>
    </div>
  );
}

export default App;
