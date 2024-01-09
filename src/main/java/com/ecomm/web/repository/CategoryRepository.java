package com.ecomm.web.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import com.ecomm.web.model.product.Category;

@Repository
public interface CategoryRepository extends JpaRepository<Category,Integer> {
    @Query(value = "SELECT * FROM product.category WHERE parent_id IS NULL", nativeQuery = true)
    List<Category> findAllBaseCategories();
    @Query(value = "SELECT c1.* FROM product.category c1 JOIN product.category c2 ON c1.parent_id = c2.category_id WHERE c2.category_id = :categoryId", nativeQuery = true)
    List<Category> findSubCategoriesByBaseCategories(Integer categoryId);
}