// Seeds a small, realistic dataset for Agentforce learning:
// - Account + Contact
// - Product2 + Standard Price Book entries
// - Order + OrderItems
// - Shipment__c linked to Order
// - Case linked to Order (Case.Related_Order__c)
// - Return__c + Return_Line__c linked to Order/Case/OrderItem

String demoAccountName = 'Agentforce Demo Account';
String demoContactLastName = 'Customer';
String demoContactFirstName = 'Alex';
String orderDescription = 'Agentforce Seed Order';
String seedTrackingNumber = '1ZAFSEED0001';
String seedRmaNumber = 'RMA-AF-0001';

String orderStatus = 'Draft';
Set<String> allowedOrderStatuses = new Set<String>();
for (Schema.PicklistEntry entry : Order.Status.getDescribe().getPicklistValues()) {
    allowedOrderStatuses.add(entry.getValue());
}
if (!allowedOrderStatuses.contains(orderStatus) && !Order.Status.getDescribe().getPicklistValues().isEmpty()) {
    orderStatus = Order.Status.getDescribe().getPicklistValues()[0].getValue();
}

// Standard Price Book
Pricebook2 standardPricebook = [
    SELECT Id, IsActive
    FROM Pricebook2
    WHERE IsStandard = true
    LIMIT 1
];
if (!standardPricebook.IsActive) {
    standardPricebook.IsActive = true;
    update standardPricebook;
}

// Account
Account demoAccount;
List<Account> accounts = [SELECT Id, Name FROM Account WHERE Name = :demoAccountName LIMIT 1];
if (!accounts.isEmpty()) {
    demoAccount = accounts[0];
} else {
    demoAccount = new Account(Name = demoAccountName);
    insert demoAccount;
}

// Contact
Contact demoContact;
List<Contact> contacts = [
    SELECT Id, FirstName, LastName, Email
    FROM Contact
    WHERE AccountId = :demoAccount.Id AND LastName = :demoContactLastName AND FirstName = :demoContactFirstName
    LIMIT 1
];
if (!contacts.isEmpty()) {
    demoContact = contacts[0];
} else {
    demoContact = new Contact(
        AccountId = demoAccount.Id,
        FirstName = demoContactFirstName,
        LastName = demoContactLastName,
        Email = 'alex.customer@example.com'
    );
    insert demoContact;
}

// Products
Map<String, Decimal> productPricesByName = new Map<String, Decimal>{
    'Widget' => 19.99,
    'Gadget' => 49.00
};

Map<String, Product2> productsByName = new Map<String, Product2>();
for (Product2 existingProduct : [
    SELECT Id, Name, IsActive
    FROM Product2
    WHERE Name IN :productPricesByName.keySet()
]) {
    productsByName.put(existingProduct.Name, existingProduct);
}

List<Product2> productsToInsert = new List<Product2>();
for (String productName : productPricesByName.keySet()) {
    if (!productsByName.containsKey(productName)) {
        productsToInsert.add(new Product2(Name = productName, IsActive = true));
    }
}
if (!productsToInsert.isEmpty()) {
    insert productsToInsert;
    for (Product2 insertedProduct : productsToInsert) {
        productsByName.put(insertedProduct.Name, insertedProduct);
    }
}

// Standard Price Book Entries
Map<Id, PricebookEntry> pbesByProductId = new Map<Id, PricebookEntry>();
Set<Id> productIds = new Set<Id>();
for (Product2 productRecord : productsByName.values()) {
    productIds.add(productRecord.Id);
}
for (PricebookEntry existingPbe : [
    SELECT Id, Product2Id, UnitPrice, IsActive
    FROM PricebookEntry
    WHERE Pricebook2Id = :standardPricebook.Id AND Product2Id IN :productIds
]) {
    pbesByProductId.put(existingPbe.Product2Id, existingPbe);
}

List<PricebookEntry> pbesToInsert = new List<PricebookEntry>();
for (String productName : productsByName.keySet()) {
    Product2 productRecord = productsByName.get(productName);
    if (!pbesByProductId.containsKey(productRecord.Id)) {
        pbesToInsert.add(new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = productRecord.Id,
            UnitPrice = productPricesByName.get(productName),
            IsActive = true,
            UseStandardPrice = false
        ));
    }
}
if (!pbesToInsert.isEmpty()) {
    insert pbesToInsert;
    for (PricebookEntry insertedPbe : pbesToInsert) {
        pbesByProductId.put(insertedPbe.Product2Id, insertedPbe);
    }
}

// Order
Order demoOrder;
List<Order> orders = [
    SELECT Id, AccountId, EffectiveDate, Status, Pricebook2Id, Description
    FROM Order
    WHERE AccountId = :demoAccount.Id AND Description = :orderDescription
    LIMIT 1
];
if (!orders.isEmpty()) {
    demoOrder = orders[0];
} else {
    demoOrder = new Order(
        AccountId = demoAccount.Id,
        EffectiveDate = Date.today().addDays(-7),
        Status = orderStatus,
        Pricebook2Id = standardPricebook.Id,
        Description = orderDescription
    );
    insert demoOrder;
}

// Order Items (OrderProduct / OrderItem)
Map<Id, OrderItem> existingOrderItemsByPbeId = new Map<Id, OrderItem>();
for (OrderItem existingItem : [
    SELECT Id, OrderId, PricebookEntryId, Quantity, UnitPrice
    FROM OrderItem
    WHERE OrderId = :demoOrder.Id
]) {
    existingOrderItemsByPbeId.put(existingItem.PricebookEntryId, existingItem);
}

List<OrderItem> orderItemsToInsert = new List<OrderItem>();
for (String productName : productsByName.keySet()) {
    Product2 productRecord = productsByName.get(productName);
    PricebookEntry pbe = pbesByProductId.get(productRecord.Id);
    if (pbe == null || existingOrderItemsByPbeId.containsKey(pbe.Id)) continue;

    Decimal unitPrice = productPricesByName.get(productName);
    Decimal quantity = (productName == 'Widget') ? 2 : 1;
    orderItemsToInsert.add(new OrderItem(
        OrderId = demoOrder.Id,
        PricebookEntryId = pbe.Id,
        Quantity = quantity,
        UnitPrice = unitPrice
    ));
}
if (!orderItemsToInsert.isEmpty()) {
    insert orderItemsToInsert;
}

OrderItem sampleOrderItem = [
    SELECT Id, Quantity
    FROM OrderItem
    WHERE OrderId = :demoOrder.Id
    ORDER BY CreatedDate ASC
    LIMIT 1
];

// Shipment__c
List<Shipment__c> existingShipments = [
    SELECT Id, Tracking_Number__c
    FROM Shipment__c
    WHERE Tracking_Number__c = :seedTrackingNumber
    LIMIT 1
];
if (existingShipments.isEmpty()) {
    insert new Shipment__c(
        Order__c = demoOrder.Id,
        Carrier__c = 'UPS',
        Tracking_Number__c = seedTrackingNumber,
        ETA__c = Date.today().addDays(2),
        Delivery_Status__c = 'Shipped',
        Notes__c = 'Seed shipment for Agentforce learning.'
    );
}

// Case
Case demoCase;
List<Case> cases = [
    SELECT Id, Subject, AccountId, ContactId, Related_Order__c
    FROM Case
    WHERE AccountId = :demoAccount.Id AND Subject = 'Agentforce: Where is my order?'
    LIMIT 1
];
if (!cases.isEmpty()) {
    demoCase = cases[0];
    if (demoCase.Related_Order__c == null) {
        demoCase.Related_Order__c = demoOrder.Id;
        update demoCase;
    }
} else {
    demoCase = new Case(
        AccountId = demoAccount.Id,
        ContactId = demoContact.Id,
        Subject = 'Agentforce: Where is my order?',
        Description = 'Customer asked for shipment status and tracking.'
    );
    demoCase.Related_Order__c = demoOrder.Id;
    insert demoCase;
}

// Return__c (upsert by External Id / unique key)
Return__c demoReturn = new Return__c(
    RMA_Number__c = seedRmaNumber,
    Order__c = demoOrder.Id,
    Case__c = demoCase.Id,
    Status__c = 'Requested',
    Reason__c = 'Damaged',
    Refund_Amount__c = 19.99,
    Notes__c = 'Seed return request for Agentforce learning.'
);
upsert demoReturn Return__c.Fields.RMA_Number__c;

// Return_Line__c
List<Return_Line__c> existingReturnLines = [
    SELECT Id
    FROM Return_Line__c
    WHERE Return__c = :demoReturn.Id AND Order_Item__c = :sampleOrderItem.Id
    LIMIT 1
];
if (existingReturnLines.isEmpty()) {
    insert new Return_Line__c(
        Return__c = demoReturn.Id,
        Order_Item__c = sampleOrderItem.Id,
        Quantity__c = 1,
        Condition__c = 'Opened',
        Notes__c = 'Customer reports damage on receipt.'
    );
}

System.debug(LoggingLevel.INFO, 'Seed complete.');
System.debug(LoggingLevel.INFO, 'Account: ' + demoAccount.Id);
System.debug(LoggingLevel.INFO, 'Contact: ' + demoContact.Id);
System.debug(LoggingLevel.INFO, 'Order: ' + demoOrder.Id);
System.debug(LoggingLevel.INFO, 'Case: ' + demoCase.Id);
System.debug(LoggingLevel.INFO, 'Return (RMA): ' + seedRmaNumber);
