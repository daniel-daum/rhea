import { useState } from "react";

import Sidebar from "./components/sidebar/sidebar/Sidebar";
import GroceryView from "./components/views/GroceryView";
import ReceiptView from "./components/views/RecieptView";
import StoreView from "./components/views/StoreView";

function App() {
  const [activeView, setActiveView] = useState("Store");

  const renderView = () => {
    switch (activeView) {
      case "Store":
        return <StoreView />;
      case "Reciept":
        return <ReceiptView />;
      case "Groceries":
        return <GroceryView />;
      default:
        return <StoreView />;
    }
  };

  return (
    <div style={{ display: "flex" }}>
      <Sidebar onViewChange={setActiveView}></Sidebar>
      <div style={{ flex: 1, padding: "2em" }}>
        {renderView()}
      </div>
    </div>
  );
}

export default App;
