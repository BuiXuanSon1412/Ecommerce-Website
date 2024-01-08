package com.ecomm.web.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import com.ecomm.web.model.shopping.OrderItem;

@Repository
public interface OrderRepository extends JpaRepository<OrderItem, Integer> {
    @Query(value = "SELECT * FROM shopping.order_item ORDER BY modified_at DESC", nativeQuery = true)
    List<OrderItem> findOrderItemsTimeOrderByStore(Integer storeId);

}
