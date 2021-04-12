# Mini Document Storage

## Motivation

Modern software deployment often requires persistent data storage.  Many times, designs are not finalized when coding starts, while future needs and directions require flexibility.  Generally projects must choose between classic highly-structured schema (SQL) and relatively newer no-schema document storage.  Highly-structured schema deployments offer high-performance and low-cost, but the very nature of the approach means it can require a lot of resources to configure and maintain.  Document storage provides a fully dynamic schema, but can suffer performance issues under large datasets, and is often much more costly to deploy.

The motivation behind Mini Document Storage is to provide a flexible document storage solution while providing a low-cost and high-performance deployment.  The provided reference implementations of Mini Document Storage achieve these goals by presenting a highly flexible and comprehensive key/value property interface to end applications, using either in-memory or SQLite for local data storage and recommending MySQL for cloud data storage, and providing higher-level constructs to serve data scoping and performance.  

## Basic Usage Overview

In Mini Document Storage, the fundamental storage object is a Document much like many other document storage solutions.  The Document is simply a key/value store with an id and type.  There are no required keys and the system will automatically maintain “creationDate” and “modificationDate” info.  Documents can be queried by id (individual) or by type (all).

Quite often, a deployment needs to maintain various groups of Documents.  Mini Document Storage provides the higher-level construct Collection, which has a Document type, name, and inclusion method.  The inclusion method is applied to all Documents of the given type as they are created and updated to keep the Collection up-to-date.  At any time, the Collection can be queried to retrieve its contents.

In addition, deployments often need to be able to access Documents efficiently given some data element unique to the Document (such as a file path or email address).  Mini Document Storage provides the higher-level construct Index, which has a Document type, name, and key method.  The key method is applied to all Documents of the given type as they are created and updated to keep the Index up-to-date.  Any any time, the Index can be queried with specific keys to retrieve the corresponding Documents.

Mini Document Storage also provides basic, global key/value storage that deployments can use to store non-Document basic data.

## Deployment Scenarios

Mini Document Storage is designed to be just as flexible in deployment as it is in design.  To that end, the Reference Implementation provides in-memory Ephemeral storage, SQLite-based local storage, and for all-Swift environments, Server storage.

The application API interface is identical, by design, allowing an application to easily move between deployment scenarios as the project develops and grows, with minimal impact on the custom application code.  Mini Document storage is designed to allow an application to use Ephemeral storage for initial development (where no data is retained from run-to-run), then slide to SQLite storage for data persistence, then even Client/Server to move the storage from local to the cloud.  In this scenario, all requisite support modules are provided by the language/environment Toolboxes, allowing the application to make minimal code changes to migrate as desired.

## Reference Implementations

The following Reference Implementations are provided as part of this repository:

**Swift:** Local Ephemeral, Local SQLite, Remote Client, and Remote Server.</br>
(Requires [Swift Toolbox](https://github.com/StevoGTA/SwiftToolbox))

**C++:** Local Ephemeral and Local SQLite.</br>
(Requires [C++ Toolbox](https://github.com/StevoGTA/CppToolbox))

**Android:** Local Ephemeral and Local SQLite.</br>
(Requires [Android Toolbox](https://github.com/StevoGTA/AndroidToolbox))

## API

For now, see MDSDocument and MDSDocumentStorage for details.  More info to come...

## Coming Soon...

High-level constructs Association and Cache.
