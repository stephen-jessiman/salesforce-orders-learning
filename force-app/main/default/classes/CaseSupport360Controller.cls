public with sharing class CaseSupport360Controller {
    @AuraEnabled(cacheable=true)
    public static Support360Response getSupport360(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('caseId is required.');
        }

        Case c = [
            SELECT Id, CaseNumber, Subject, Status, Related_Order__c, AccountId, ContactId
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        Support360Response resp = new Support360Response();
        resp.caseSummary = new CaseSummary(c);

        if (c.Related_Order__c == null) {
            resp.message = 'Set Case.Related Order to see Order/Shipment/Return context.';
            return resp;
        }

        Order o;
        try {
            o = [
                SELECT Id, OrderNumber, Status, EffectiveDate, PoNumber, Description, TotalAmount, AccountId
                FROM Order
                WHERE Id = :c.Related_Order__c
                LIMIT 1
            ];
        } catch (Exception e) {
            resp.message = 'Related Order is not accessible or does not exist.';
            return resp;
        }

        resp.order = new OrderSummary(o);

        List<OrderItem> orderItems = [
            SELECT Id, Quantity, UnitPrice, TotalPrice, PricebookEntry.Product2.Name
            FROM OrderItem
            WHERE OrderId = :o.Id
            ORDER BY CreatedDate ASC
            LIMIT 50
        ];
        orderItems = (List<OrderItem>) Security.stripInaccessible(AccessType.READABLE, orderItems).getRecords();
        resp.orderItems = new List<OrderItemSummary>();
        for (OrderItem oi : orderItems) {
            resp.orderItems.add(new OrderItemSummary(oi));
        }

        List<Shipment__c> shipments = [
            SELECT Id, Name, Carrier__c, Tracking_Number__c, ETA__c, Delivery_Status__c, Notes__c
            FROM Shipment__c
            WHERE Order__c = :o.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        shipments = (List<Shipment__c>) Security.stripInaccessible(AccessType.READABLE, shipments).getRecords();
        if (!shipments.isEmpty()) {
            resp.shipment = new ShipmentSummary(shipments[0]);
        }

        List<Return__c> returns = [
            SELECT Id, Name, RMA_Number__c, Status__c, Reason__c, Refund_Amount__c, Notes__c, Case__c
            FROM Return__c
            WHERE (Case__c = :c.Id) OR (Order__c = :o.Id)
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        returns = (List<Return__c>) Security.stripInaccessible(AccessType.READABLE, returns).getRecords();
        if (!returns.isEmpty()) {
            Return__c r = returns[0];
            resp.returnRequest = new ReturnSummary(r);

            List<Return_Line__c> returnLines = [
                SELECT Id, Name, Quantity__c, Condition__c, Notes__c, Order_Item__c, Order_Item__r.PricebookEntry.Product2.Name
                FROM Return_Line__c
                WHERE Return__c = :r.Id
                ORDER BY CreatedDate ASC
                LIMIT 50
            ];
            returnLines = (List<Return_Line__c>) Security.stripInaccessible(AccessType.READABLE, returnLines).getRecords();
            resp.returnLines = new List<ReturnLineSummary>();
            for (Return_Line__c rl : returnLines) {
                resp.returnLines.add(new ReturnLineSummary(rl));
            }
        }

        return resp;
    }

    public class Support360Response {
        @AuraEnabled public CaseSummary caseSummary;
        @AuraEnabled public OrderSummary order;
        @AuraEnabled public List<OrderItemSummary> orderItems;
        @AuraEnabled public ShipmentSummary shipment;
        @AuraEnabled public ReturnSummary returnRequest;
        @AuraEnabled public List<ReturnLineSummary> returnLines;
        @AuraEnabled public String message;
    }

    public class CaseSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String subject;
        @AuraEnabled public String status;
        @AuraEnabled public Id relatedOrderId;

        public CaseSummary(Case c) {
            c = (Case) Security.stripInaccessible(AccessType.READABLE, new List<SObject>{ c }).getRecords()[0];
            this.id = c.Id;
            this.caseNumber = c.CaseNumber;
            this.subject = c.Subject;
            this.status = c.Status;
            this.relatedOrderId = (Id) c.get('Related_Order__c');
        }
    }

    public class OrderSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String orderNumber;
        @AuraEnabled public String status;
        @AuraEnabled public Date effectiveDate;
        @AuraEnabled public String poNumber;
        @AuraEnabled public Decimal totalAmount;

        public OrderSummary(Order o) {
            o = (Order) Security.stripInaccessible(AccessType.READABLE, new List<SObject>{ o }).getRecords()[0];
            this.id = o.Id;
            this.orderNumber = o.OrderNumber;
            this.status = o.Status;
            this.effectiveDate = o.EffectiveDate;
            this.poNumber = o.PoNumber;
            this.totalAmount = o.TotalAmount;
        }
    }

    public class OrderItemSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String productName;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal totalPrice;

        public OrderItemSummary(OrderItem oi) {
            this.id = oi.Id;
            this.quantity = oi.Quantity;
            this.unitPrice = oi.UnitPrice;
            this.totalPrice = oi.TotalPrice;
            this.productName = (oi.PricebookEntry != null && oi.PricebookEntry.Product2 != null) ? oi.PricebookEntry.Product2.Name : null;
        }
    }

    public class ShipmentSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String carrier;
        @AuraEnabled public String trackingNumber;
        @AuraEnabled public Date eta;
        @AuraEnabled public String deliveryStatus;

        public ShipmentSummary(Shipment__c sObj) {
            this.id = sObj.Id;
            this.name = sObj.Name;
            this.carrier = sObj.Carrier__c;
            this.trackingNumber = sObj.Tracking_Number__c;
            this.eta = sObj.ETA__c;
            this.deliveryStatus = sObj.Delivery_Status__c;
        }
    }

    public class ReturnSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String rmaNumber;
        @AuraEnabled public String status;
        @AuraEnabled public String reason;
        @AuraEnabled public Decimal refundAmount;

        public ReturnSummary(Return__c r) {
            this.id = r.Id;
            this.name = r.Name;
            this.rmaNumber = r.RMA_Number__c;
            this.status = r.Status__c;
            this.reason = r.Reason__c;
            this.refundAmount = r.Refund_Amount__c;
        }
    }

    public class ReturnLineSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String productName;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public String condition;
        @AuraEnabled public String notes;

        public ReturnLineSummary(Return_Line__c rl) {
            this.id = rl.Id;
            this.name = rl.Name;
            this.quantity = rl.Quantity__c;
            this.condition = rl.Condition__c;
            this.notes = rl.Notes__c;
            this.productName = (rl.Order_Item__r != null && rl.Order_Item__r.PricebookEntry != null && rl.Order_Item__r.PricebookEntry.Product2 != null)
                ? rl.Order_Item__r.PricebookEntry.Product2.Name
                : null;
        }
    }
}
