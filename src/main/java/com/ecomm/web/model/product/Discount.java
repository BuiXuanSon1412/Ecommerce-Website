package com.ecomm.web.model.product;

import java.time.LocalDate;

import com.ecomm.web.model.store.Store;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "discount", schema = "product")
public class Discount {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "discount_id")
    private Integer id;
    private String name;
    @Column(name = "description")
    private String desc;
    @Column(name = "discount_percent")
    private Double disc;
    private LocalDate startDate;
    private LocalDate endDate;
    private Boolean isActive;
    @ManyToOne
    @JoinColumn(name = "store_id")
    private Store store;
}
