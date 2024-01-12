package com.ecomm.web.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import com.ecomm.web.model.product.Inventory;
import com.ecomm.web.model.product.Product;

@Repository
public interface InventoryRepository extends JpaRepository<Inventory, Integer> {
    @Query(value = "SELECT quantity FROM product.inventory WHERE product_id = :productId", nativeQuery = true)
    Integer findQuantityByProduct(Integer productId);  
    Inventory findByProduct(Product product);
}
