package com.ecomm.web.model.delivery;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
@Entity
@Table(schema = "delivery", name = "delivery_provider")
public class DeliveryProvider {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "delivery_provider_id")
    private Integer id;
    private String name;
    private String contactEmail;
    private String contactPhone;
    private String websiteUrl;
}
