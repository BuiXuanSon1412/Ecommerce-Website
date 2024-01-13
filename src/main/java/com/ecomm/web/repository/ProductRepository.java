package com.ecomm.web.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import com.ecomm.web.model.product.Product;
import com.ecomm.web.model.store.Store;

@Repository
public interface ProductRepository extends JpaRepository<Product, Integer> {
    List<Product> findByStore(Store store);

    @Query(value = "SELECT DISTINCT p.* FROM product.product p JOIN product.category c1 ON p.category_id = c1.category_id JOIN product.category c2 ON c1.parent_id = c2.category_id WHERE LOWER(p.name) LIKE CONCAT('%', :name, '%') AND c2.category_id = :categoryId", nativeQuery = true)
    List<Product> findByNameAndCategory(String name, Integer categoryId);

    @Query(value = "SELECT DISTINCT p.* FROM product.product p JOIN product.category c1 ON p.category_id = c1.category_id JOIN product.category c2 ON c1.parent_id = c2.category_id WHERE c2.category_id = :categoryId", nativeQuery = true)
    List<Product> findByBaseCategory(Integer categoryId);

    @Query(value = "SELECT DISTINCT p.* FROM product.product p WHERE LOWER(p.name) LIKE CONCAT('%', :name, '%')", nativeQuery = true)
    Product findByName(String name);
    @Query(value = "SELECT * FROM product.product ORDER BY created_at DESC", nativeQuery = true)
    List<Product> findNewReleases();
    @Query(value = "select distinct p.* from product.product as p join (select oi.product_id,sum(quantity) as quantity from shopping.order_item as oi group by oi.product_id) as tempo on tempo.product_id=p.product_id order by tempo.quantity desc", nativeQuery = true)
    List<Product> findPopularItems();
}
