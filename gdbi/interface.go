/*
Core Graph Database interfaces
*/

package gdbi

import (
	"context"

	"github.com/bmeg/arachne/aql"
	"github.com/bmeg/arachne/kvi"
)

// InPipe incoming traveler messages
type InPipe <-chan *Traveler

// OutPipe collects output traveler messages
type OutPipe chan<- *Traveler

// DataElement is a single data element
type DataElement struct {
	ID       string
	Label    string
	From, To string
	Data     map[string]interface{}
	Row      []DataElement
	Value    interface{}
}

// Traveler is a query element that traverse the graph
type Traveler struct {
	current     *DataElement
	marks       map[string]*DataElement
	Count       int64
	GroupCounts map[string]int64
	value       interface{}
}

// DataType is a possible output data type
type DataType uint8

// DataTypes
const (
	NoData DataType = iota
	VertexData
	EdgeData
	CountData
	GroupCountData
	ValueData
	RowData
)

// ElementLookup request to look up data
type ElementLookup struct {
	ID     string
	Ref    interface{}
	Vertex *aql.Vertex
	Edge   *aql.Edge
}

// GraphDB is the base interface for graph databases
type GraphDB interface {
	AddGraph(string) error
	DeleteGraph(string) error
	GetGraphs() []string
	Graph(id string) GraphInterface

	Close()
}

// GraphInterface is the base Graph data storage interface, the PipeEngine will be able
// to run queries on a data system backend that implements this interface
type GraphInterface interface {
	Compiler() Compiler

	GetTimestamp() string

	//Query() QueryInterface

	GetVertex(key string, load bool) *aql.Vertex
	GetEdge(key string, load bool) *aql.Edge

	AddVertex(vertex []*aql.Vertex) error
	AddEdge(edge []*aql.Edge) error

	DelVertex(key string) error
	DelEdge(key string) error

	VertexLabelScan(ctx context.Context, label string) chan string
	//EdgeLabelScan(ctx context.Context, label string) chan string

	AddVertexIndex(label string, field string) error
	//AddEdgeIndex(label string, field string) error

	GetVertexIndexList() chan aql.IndexID

	DeleteVertexIndex(label string, field string) error
	//DeleteEdgeIndex(label string, field string) error

	GetVertexTermCount(ctx context.Context, label string, field string) chan aql.IndexTermCount
	//GetEdgeTermCount(ctx context.Context, label string, field string) chan aql.IndexTermCount

	AddEdgeGen(*aql.EdgeGen) error
	DeleteEdgeGen(key string) error
	ListEdgeGen() chan string
	GetEdgeGen(key string) *aql.EdgeGen

	GetVertexList(ctx context.Context, load bool) <-chan *aql.Vertex
	GetEdgeList(ctx context.Context, load bool) <-chan *aql.Edge

	GetVertexChannel(req chan ElementLookup, load bool) chan ElementLookup
	GetOutChannel(req chan ElementLookup, load bool, edgeLabels []string) chan ElementLookup
	GetInChannel(req chan ElementLookup, load bool, edgeLabels []string) chan ElementLookup
	GetOutEdgeChannel(req chan ElementLookup, load bool, edgeLabels []string) chan ElementLookup
	GetInEdgeChannel(req chan ElementLookup, load bool, edgeLabels []string) chan ElementLookup
}

// Manager is a resource manager that is passed to processors to allow them ]
// to make resource requests
type Manager interface {
	//Get handle to temporary KeyValue store driver
	GetTempKV() kvi.KVInterface
	Cleanup()
}

// Compiler takes a aql query and turns it into an executable pipeline
type Compiler interface {
	Compile(stmts []*aql.GraphStatement, workDir string) (Pipeline, error)
}

// Processor is the interface for a step in the pipe engine
type Processor interface {
	Process(ctx context.Context, man Manager, in InPipe, out OutPipe) context.Context
}

// Pipeline represents a set of processors
type Pipeline interface {
	Processors() []Processor
	DataType() DataType
	RowTypes() []DataType
}
