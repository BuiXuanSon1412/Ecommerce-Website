package com.ecomm.web.model.shopping;

import com.ecomm.web.model.delivery.DeliveryProvider;
import com.ecomm.web.model.product.Product;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.Builder;

@Data
@Builder
@Entity
@Table(schema = "shopping", name = "order_item")
public class OrderItem {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "order_item_id")
    private Integer id;
    @ManyToOne
    @JoinColumn(name = "order_detail_id")
    private OrderDetail orderDetail;
    @ManyToOne
    @JoinColumn(name = "product_id")
    private Product product;
    private Integer quantity;
    private String condition;
    @ManyToOne
    @JoinColumn(name = "delivery_provider_id")
    private DeliveryProvider deliveryProvider;  
}

