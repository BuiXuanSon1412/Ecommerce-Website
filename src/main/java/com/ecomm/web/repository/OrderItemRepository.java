package com.ecomm.web.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import com.ecomm.web.model.shopping.OrderItem;

@Repository
public interface OrderItemRepository extends JpaRepository<OrderItem, Integer> {
    @Query(value = "SELECT oi.* FROM shopping.order_item oi JOIN product.product p USING (product_id) WHERE store_id = :storeId ORDER BY oi.modified_at DESC", nativeQuery = true)
    List<OrderItem> findOrderItemsByStore(Integer storeId);
    @Query(value = "SELECT oi.* FROM shopping.order_item oi JOIN product.product p USING (product_id) where oi.condition = :condition AND p.store_id = :storeId ORDER BY modified_at DESC", nativeQuery = true)
    List<OrderItem> findOrderItemsByStoreAndCondition(Integer storeId, String condition);
}
