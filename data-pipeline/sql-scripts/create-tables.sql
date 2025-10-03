-- SQL Script to create tables for RIA system
-- This script creates the necessary tables for storing SAP data

-- Raw SAP ECC Data Table
CREATE TABLE [dbo].[SapEccRawData] (
    [Id] [uniqueidentifier] NOT NULL DEFAULT NEWID(),
    [CustomerID] [nvarchar](50) NOT NULL,
    [OrderNumber] [nvarchar](50) NOT NULL,
    [OrderDate] [datetime2](7) NOT NULL,
    [ProductCode] [nvarchar](50) NOT NULL,
    [Quantity] [decimal](18,2) NOT NULL,
    [UnitPrice] [decimal](18,2) NOT NULL,
    [TotalAmount] [decimal](18,2) NOT NULL,
    [Status] [nvarchar](50) NOT NULL,
    [SalesRep] [nvarchar](100) NULL,
    [Region] [nvarchar](100) NULL,
    [ProcessedDate] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
    [DataSource] [nvarchar](50) NOT NULL DEFAULT 'SAP_ECC',
    [IsActive] [bit] NOT NULL DEFAULT 1,
    [IsDeleted] [bit] NOT NULL DEFAULT 0,
    [ValidationErrors] [nvarchar](max) NULL,
    CONSTRAINT [PK_SapEccRawData] PRIMARY KEY CLUSTERED ([Id] ASC)
);

-- Raw SAP BW Data Table
CREATE TABLE [dbo].[SapBwRawData] (
    [Id] [uniqueidentifier] NOT NULL DEFAULT NEWID(),
    [CustomerID] [nvarchar](50) NOT NULL,
    [ProductCode] [nvarchar](50) NOT NULL,
    [SalesAmount] [decimal](18,2) NOT NULL,
    [SalesQuantity] [decimal](18,2) NOT NULL,
    [SalesDate] [datetime2](7) NOT NULL,
    [SalesRep] [nvarchar](100) NULL,
    [Region] [nvarchar](100) NULL,
    [Channel] [nvarchar](50) NULL,
    [ProductCategory] [nvarchar](100) NULL,
    [CustomerSegment] [nvarchar](100) NULL,
    [ProcessedDate] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
    [DataSource] [nvarchar](50) NOT NULL DEFAULT 'SAP_BW',
    [IsActive] [bit] NOT NULL DEFAULT 1,
    [IsDeleted] [bit] NOT NULL DEFAULT 0,
    [ValidationErrors] [nvarchar](max) NULL,
    CONSTRAINT [PK_SapBwRawData] PRIMARY KEY CLUSTERED ([Id] ASC)
);

-- Processed Customer Data Table
CREATE TABLE [dbo].[Customers] (
    [Id] [uniqueidentifier] NOT NULL DEFAULT NEWID(),
    [CustomerID] [nvarchar](50) NOT NULL,
    [CustomerName] [nvarchar](200) NULL,
    [CustomerSegment] [nvarchar](100) NULL,
    [Region] [nvarchar](100) NULL,
    [SalesRep] [nvarchar](100) NULL,
    [TotalOrders] [int] NOT NULL DEFAULT 0,
    [TotalSalesAmount] [decimal](18,2) NOT NULL DEFAULT 0,
    [LastOrderDate] [datetime2](7) NULL,
    [CreatedDate] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
    [UpdatedDate] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
    [IsActive] [bit] NOT NULL DEFAULT 1,
    CONSTRAINT [PK_Customers] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [UQ_Customers_CustomerID] UNIQUE ([CustomerID])
);

-- Processed Product Data Table
CREATE TABLE [dbo].[Products] (
    [Id] [uniqueidentifier] NOT NULL DEFAULT NEWID(),
    [ProductCode] [nvarchar](50) NOT NULL,
    [ProductName] [nvarchar](200) NULL,
    [ProductCategory] [nvarchar](100) NULL,
    [UnitPrice] [decimal](18,2) NULL,
    [TotalQuantitySold] [decimal](18,2) NOT NULL DEFAULT 0,
    [TotalSalesAmount] [decimal](18,2) NOT NULL DEFAULT 0,
    [CreatedDate] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
    [UpdatedDate] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
    [IsActive] [bit] NOT NULL DEFAULT 1,
    CONSTRAINT [PK_Products] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [UQ_Products_ProductCode] UNIQUE ([ProductCode])
);

-- Processed Sales Data Table
CREATE TABLE [dbo].[Sales] (
    [Id] [uniqueidentifier] NOT NULL DEFAULT NEWID(),
    [CustomerID] [nvarchar](50) NOT NULL,
    [ProductCode] [nvarchar](50) NOT NULL,
    [OrderNumber] [nvarchar](50) NULL,
    [SalesDate] [datetime2](7) NOT NULL,
    [SalesAmount] [decimal](18,2) NOT NULL,
    [SalesQuantity] [decimal](18,2) NOT NULL,
    [UnitPrice] [decimal](18,2) NOT NULL,
    [Region] [nvarchar](100) NULL,
    [Channel] [nvarchar](50) NULL,
    [SalesRep] [nvarchar](100) NULL,
    [DataSource] [nvarchar](50) NOT NULL,
    [CreatedDate] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
    [IsActive] [bit] NOT NULL DEFAULT 1,
    CONSTRAINT [PK_Sales] PRIMARY KEY CLUSTERED ([Id] ASC)
);

-- Bot Context Table for storing conversation context
CREATE TABLE [dbo].[BotContext] (
    [Id] [uniqueidentifier] NOT NULL DEFAULT NEWID(),
    [UserId] [nvarchar](100) NOT NULL,
    [ConversationId] [nvarchar](100) NOT NULL,
    [ContextData] [nvarchar](max) NULL,
    [LastActivity] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
    [CreatedDate] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
    [IsActive] [bit] NOT NULL DEFAULT 1,
    CONSTRAINT [PK_BotContext] PRIMARY KEY CLUSTERED ([Id] ASC)
);

-- Indexes for better performance
CREATE NONCLUSTERED INDEX [IX_SapEccRawData_CustomerID] ON [dbo].[SapEccRawData] ([CustomerID]);
CREATE NONCLUSTERED INDEX [IX_SapEccRawData_OrderNumber] ON [dbo].[SapEccRawData] ([OrderNumber]);
CREATE NONCLUSTERED INDEX [IX_SapEccRawData_OrderDate] ON [dbo].[SapEccRawData] ([OrderDate]);
CREATE NONCLUSTERED INDEX [IX_SapEccRawData_ProcessedDate] ON [dbo].[SapEccRawData] ([ProcessedDate]);

CREATE NONCLUSTERED INDEX [IX_SapBwRawData_CustomerID] ON [dbo].[SapBwRawData] ([CustomerID]);
CREATE NONCLUSTERED INDEX [IX_SapBwRawData_ProductCode] ON [dbo].[SapBwRawData] ([ProductCode]);
CREATE NONCLUSTERED INDEX [IX_SapBwRawData_SalesDate] ON [dbo].[SapBwRawData] ([SalesDate]);
CREATE NONCLUSTERED INDEX [IX_SapBwRawData_ProcessedDate] ON [dbo].[SapBwRawData] ([ProcessedDate]);

CREATE NONCLUSTERED INDEX [IX_Sales_CustomerID] ON [dbo].[Sales] ([CustomerID]);
CREATE NONCLUSTERED INDEX [IX_Sales_ProductCode] ON [dbo].[Sales] ([ProductCode]);
CREATE NONCLUSTERED INDEX [IX_Sales_SalesDate] ON [dbo].[Sales] ([SalesDate]);
CREATE NONCLUSTERED INDEX [IX_Sales_Region] ON [dbo].[Sales] ([Region]);

CREATE NONCLUSTERED INDEX [IX_BotContext_UserId] ON [dbo].[BotContext] ([UserId]);
CREATE NONCLUSTERED INDEX [IX_BotContext_ConversationId] ON [dbo].[BotContext] ([ConversationId]);
CREATE NONCLUSTERED INDEX [IX_BotContext_LastActivity] ON [dbo].[BotContext] ([LastActivity]);
