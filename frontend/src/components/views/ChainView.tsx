import { useState, useEffect } from "react";
import axios from "axios";
import "./chainview.css";

type Chain = { id: number; name: string };
type ToastType = "success" | "error";
type ToastState = { message: string; type: ToastType } | null;

const MOCK_URL = "http://localhost:3000/api/chains";

// Toast component
function Toast({
  message,
  type,
  onClose,
}: {
  message: string;
  type: ToastType;
  onClose: () => void;
}) {
  useEffect(() => {
    const timer = setTimeout(onClose, 3000);
    return () => clearTimeout(timer);
  }, [onClose]);

  return (
    <div className="toast-container">
      <div className={`toast toast-${type}`}>{message}</div>
    </div>
  );
}

function ChainView() {
  const [chains, setChains] = useState<Chain[]>([]);
  const [createName, setCreateName] = useState("");
  const [updateId, setUpdateId] = useState<number | null>(null);
  const [updateName, setUpdateName] = useState("");
  const [deleteId, setDeleteId] = useState<number | null>(null);
  const [toast, setToast] = useState<ToastState>(null);

  const showToast = (message: string, type: ToastType) => {
    setToast({ message, type });
  };

  // Read - GET request
  const getChains = () => {
    axios
      .get(MOCK_URL)
      .then((res) => {
        setChains(res.data);
        if (res.data.length > 0) {
          setUpdateId(res.data[0].id);
          setUpdateName(res.data[0].name);
          setDeleteId(res.data[0].id);
        }
      })
      .catch(() => showToast("Failed to load chains", "error"));
  };

  useEffect(() => {
    getChains();
  }, []);

  // Create - POST request
  const createChain = (e: React.FormEvent) => {
    e.preventDefault();
    axios
      .post(MOCK_URL, { name: createName })
      .then((res) => {
        setChains([...chains, res.data]);
        setCreateName("");
        showToast("Chain created", "success");
      })
      .catch(() => showToast("Failed to create", "error"));
  };

  // Update - PUT request
  const updateChain = () => {
    axios
      .put(`${MOCK_URL}/${updateId}`, { name: updateName })
      .then((res) => {
        setChains(chains.map((c) => (c.id === res.data.id ? res.data : c)));
        showToast("Chain updated", "success");
      })
      .catch(() => showToast("Failed to update", "error"));
  };

  // Delete - DELETE request
  const deleteChain = () => {
    axios
      .delete(`${MOCK_URL}/${deleteId}`)
      .then(() => {
        const newChains = chains.filter((c) => c.id !== deleteId);
        setChains(newChains);
        setUpdateId(newChains[0]?.id || null);
        setUpdateName(newChains[0]?.name || "");
        setDeleteId(newChains[0]?.id || null);
        showToast("Chain deleted", "success");
      })
      .catch(() => showToast("Failed to delete", "error"));
  };

  return (
    <div className="chainview">
      {/* Create */}
      <div className="crud-section">
        <h3>Create Chain</h3>
        <form onSubmit={createChain}>
          <label>Chain Name: </label>
          <input
            type="text"
            value={createName}
            onChange={(e) => setCreateName(e.target.value)}
          />
          <button type="submit">Create</button>
        </form>
      </div>

      {/* Read */}
      <div className="crud-section">
        <h3>Chains</h3>
        {chains.length === 0 ? (
          <p>No chains</p>
        ) : (
          <table>
            <thead>
              <tr>
                <th>ID</th>
                <th>Name</th>
              </tr>
            </thead>
            <tbody>
              {chains.map((chain) => (
                <tr key={chain.id}>
                  <td>{chain.id}</td>
                  <td>{chain.name}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* Update */}
      {/*<div className="crud-section">
        <h3>Update Chain</h3>
        {chains.length === 0 ? (
          <p>No chains to update</p>
        ) : (
          <div>
            <label>Select Chain: </label>
            <select
              value={updateId || ""}
              onChange={(e) => {
                const id = Number(e.target.value);
                setUpdateId(id);
                setUpdateName(chains.find((c) => c.id === id)?.name || "");
              }}
            >
              {chains.map((chain) => (
                <option key={chain.id} value={chain.id}>
                  {chain.name}
                </option>
              ))}
            </select>
            <label> New Name: </label>
            <input
              type="text"
              value={updateName}
              onChange={(e) => setUpdateName(e.target.value)}
            />
            <button onClick={updateChain}>Update</button>
          </div>
        )}
      </div>*/}

      {/* Delete */}
      {/*<div className="crud-section">
        <h3>Delete Chain</h3>
        {chains.length === 0 ? (
          <p>No chains to delete</p>
        ) : (
          <div>
            <label>Select Chain: </label>
            <select
              value={deleteId || ""}
              onChange={(e) => setDeleteId(Number(e.target.value))}
            >
              {chains.map((chain) => (
                <option key={chain.id} value={chain.id}>
                  {chain.name}
                </option>
              ))}
            </select>
            <button onClick={deleteChain}>Delete</button>
          </div>
        )}
      </div>*/}

      {toast && (
        <Toast
          message={toast.message}
          type={toast.type}
          onClose={() => setToast(null)}
        />
      )}
    </div>
  );
}

export default ChainView;
