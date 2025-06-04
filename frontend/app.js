const { useState, useCallback } = React;
const { ReactFlowProvider, ReactFlow, addEdge, removeElements, Controls, Background } = ReactFlow;

const initialElements = [
  {
    id: '1',
    type: 'input',
    data: { label: 'Start Node' },
    position: { x: 250, y: 5 },
  },
  {
    id: '2',
    data: { label: 'Another Node' },
    position: { x: 100, y: 100 },
  },
  {
    id: 'e1-2',
    source: '1',
    target: '2',
    animated: true,
  },
];

function BasicFlow() {
  const [elements, setElements] = useState(initialElements);
  const onConnect = useCallback((params) => setElements((els) => addEdge(params, els)), []);
  const onElementsRemove = useCallback((elementsToRemove) => setElements((els) => removeElements(elementsToRemove, els)), []);

  return (
    <ReactFlowProvider>
      <ReactFlow
        elements={elements}
        onElementsRemove={onElementsRemove}
        onConnect={onConnect}
        deleteKeyCode={46} /* 'delete'-key */
      >
        <Controls />
        <Background />
      </ReactFlow>
    </ReactFlowProvider>
  );
}

ReactDOM.render(React.createElement(BasicFlow), document.getElementById('root'));
console.log("ReactFlow app.js loaded and attempting to render.");
